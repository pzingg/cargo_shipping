defmodule CargoShipping.RoutingService.LibgraphRouteFinder do
  @moduledoc """
  Use libgraph to build graph and select lowest cost route.
  """
  import Graph.Utils, only: [vertex_id: 1, edge_weight: 3]

  require Logger

  alias CargoShipping.VoyagePlans
  alias CargoShipping.CargoBookings.Itinerary

  defmodule Vertex do
    @moduledoc """
    Represents a vertex in a directed graph.
    """
    use Ecto.Schema

    import Ecto.Changeset

    @type_values [:DEPART, :ARRIVE, :ORIGIN, :DESTINATION]

    @primary_key false
    embedded_schema do
      field :name, :string
      field :type, Ecto.Enum, values: @type_values
      field :location, :string
      field :time, :utc_datetime
      field :voyage_number, :string
      field :voyage_id, :string
      field :index, :integer
    end

    def changeset(attrs) do
      %__MODULE__{}
      |> cast(attrs, [:name, :type, :location, :time, :voyage_number, :voyage_id, :index])
      |> validate_required([:name, :type, :location, :time])
      |> validate_inclusion(:type, @type_values)
    end

    def new(attrs), do: changeset(attrs) |> apply_changes()
  end

  @doc """
  The RouteSpecification is picked apart and adapted to the external API.
  """
  def fetch_routes_for_specification(
        %{origin: origin, destination: destination} = route_specification,
        opts
      ) do
    v_origin = %Vertex{
      name: "#{origin}:ORG",
      type: :ORIGIN,
      location: origin,
      time: route_specification.earliest_departure
    }

    v_destination = %Vertex{
      name: "#{destination}:DST",
      type: :DESTINATION,
      location: destination,
      time: route_specification.arrival_deadline
    }

    graph = build_world_graph(v_origin, v_destination, opts)

    if Keyword.get(opts, :write_dot, false) do
      {:ok, dot} = Graph.Serializers.DOT.serialize(graph)
      file_name = "#{origin}-#{destination}.dot"
      File.write(file_name, dot)
      Logger.debug("route graph written to #{file_name}")
    end

    case Keyword.get(opts, :find, :shortest) do
      :shortest ->
        case find_shortest_path(graph, v_origin, v_destination) do
          nil ->
            Logger.error("could not find shortest path in graph from #{origin} to #{destination}")
            []

          path ->
            Logger.debug("found shortest path in graph from #{origin} to #{destination}")
            [%{itinerary: itinerary_from_path(path), cost: 100}]
        end

      :all ->
        paths = find_all_paths(graph, v_origin, v_destination)

        Logger.debug(
          "found #{Enum.count(paths)} path(s) in graph from #{origin} to #{destination}"
        )

        Enum.map(paths, fn path -> {path, cost_for_path(graph, path)} end)
        |> Enum.sort(fn {_path_1, cost_1}, {_path_2, cost_2} -> cost_1 <= cost_2 end)
        |> Enum.map(fn {path, cost} ->
          %{itinerary: itinerary_from_path(path), cost: cost}
        end)
    end
  end

  def build_world_graph(v_origin, v_destination, opts) do
    minimum_layover_in_seconds = Keyword.get(opts, :mininum_layover_hours, 4) * 3_600
    voyages = VoyagePlans.list_voyages()

    internal_edges =
      Enum.reduce(voyages, [], fn voyage, acc ->
        internal_voyage_edges(voyage, acc)
      end)

    arrival_vertices = [
      v_origin
      | Enum.map(internal_edges, fn {_v_depart, v_arrive, _opts} -> v_arrive end)
    ]

    departure_vertices = [
      v_destination
      | Enum.map(internal_edges, fn {v_depart, _v_arrive, _opts} -> v_depart end)
    ]

    external_edges =
      Enum.reduce(arrival_vertices, [], fn v_arrive, acc ->
        at_origin? = v_arrive.type == :ORIGIN
        arrival_location = v_arrive.location
        earliest_departure = DateTime.add(v_arrive.time, minimum_layover_in_seconds, :second)
        arrival_voyage_number = v_arrive.voyage_number

        departure_index =
          case v_arrive.index do
            nil -> nil
            index -> index + 1
          end

        Enum.reduce(departure_vertices, acc, fn v_depart, edges ->
          departure_time_compare = DateTime.compare(v_depart.time, earliest_departure)

          {label, weight, color, style} =
            cond do
              v_depart.location != arrival_location ->
                {nil, nil, nil, nil}

              at_origin? ->
                {"RECEIVE", 1, "black", "bold"}

              v_depart.type == :DESTINATION ->
                {"CLAIM", 1, "black", "bold"}

              !is_nil(v_depart.index) && !is_nil(departure_index) &&
                v_depart.voyage_number == arrival_voyage_number &&
                  v_depart.index == departure_index ->
                {"IN_PORT", 1, "black", "bold"}

              departure_time_compare != :lt ->
                {"TRANSFER", 100, "red", "dashed"}

              true ->
                # Logger.warn(
                #   "rejecting transfer at #{arrival_location} from #{arrival_voyage_number} to #{v_depart.voyage_number}"
                # )
                # Logger.warn("arrival time   #{v_arrive.time}")
                # Logger.warn("departure_time #{v_depart.time}")
                # Logger.warn("earliest       #{earliest_departure}")
                # Logger.warn("")

                {nil, nil, nil, nil}
            end

          if is_nil(label) do
            edges
          else
            [
              {v_arrive, v_depart, [label: label, weight: weight, color: color, style: style]}
              | edges
            ]
          end
        end)
      end)

    all_vertices = departure_vertices ++ arrival_vertices
    all_edges = internal_edges ++ external_edges

    all_vertices
    |> Enum.reduce(Graph.new(), fn vertex, graph ->
      Graph.add_vertex(graph, vertex, vertex.name)
    end)
    |> Graph.add_edges(all_edges)
  end

  def find_shortest_path(graph, v_origin, v_destination) do
    Graph.a_star(graph, v_origin, v_destination, &vertex_cost/1)
  end

  def find_all_paths(graph, v_origin, v_destination),
    do: Graph.get_paths(graph, v_origin, v_destination)

  ## Private functions

  defp internal_voyage_edges(voyage, acc_0) do
    last_index = Enum.count(voyage.schedule_items) - 1

    {edges, _count, _} =
      Enum.reduce(voyage.schedule_items, {acc_0, 0, last_index}, fn leg, acc ->
        internal_leg_edges(voyage, leg, acc)
      end)

    edges
  end

  defp internal_leg_edges(voyage, leg, {edges, i, last}) do
    v_depart = %Vertex{
      name: "#{leg.departure_location}:DEP:#{voyage.voyage_number}:#{i}",
      type: :DEPART,
      location: leg.departure_location,
      time: leg.departure_time,
      voyage_id: voyage.id,
      voyage_number: voyage.voyage_number,
      index: i
    }

    v_arrive = %Vertex{
      name: "#{leg.arrival_location}:ARR:#{voyage.voyage_number}:#{i}",
      type: :ARRIVE,
      location: leg.arrival_location,
      time: leg.arrival_time,
      voyage_id: voyage.id,
      voyage_number: voyage.voyage_number,
      index: i
    }

    is_last =
      if i == last do
        ":LAST"
      else
        ""
      end

    label = "ONB:#{voyage.voyage_number}:#{i}#{is_last}"
    {[{v_depart, v_arrive, [label: label, weight: 1]} | edges], i + 1, last}
  end

  defp cost_for_path(graph, vertices) do
    {_last_id, total_cost} =
      Enum.reduce(vertices, {nil, 0}, fn v2, {v1_id, acc} ->
        v2_id = vertex_id(v2)

        if is_nil(v1_id) do
          {v2_id, 0}
        else
          {v2_id, acc + cost(graph, v1_id, v2_id, v2)}
        end
      end)

    total_cost
  end

  defp cost(%Graph{} = g, v1_id, v2_id, v2) do
    edge_weight(g, v1_id, v2_id) + vertex_cost(v2)
  end

  defp vertex_cost(_vertex), do: 0

  defp itinerary_from_path(vertices) do
    # Skip 0 and Enum.count - 1
    last_index = Enum.count(vertices) - 2

    Enum.map(1..last_index//2, fn i ->
      v_depart = Enum.at(vertices, i)
      v_arrive = Enum.at(vertices, i + 1)
      leg_from_edge(v_depart, v_arrive)
    end)
    |> Itinerary.new()
  end

  defp leg_from_edge(v_depart, v_arrive) do
    %{
      voyage_id: v_depart.voyage_id,
      load_location: v_depart.location,
      unload_location: v_arrive.location,
      load_time: v_depart.time,
      unload_time: v_arrive.time,
      status: :NOT_LOADED
    }
  end
end

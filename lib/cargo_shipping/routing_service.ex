defmodule CargoShipping.RoutingService do
  @moduledoc """
  A module that builds new routes.
  """
  import Graph.Utils, only: [vertex_id: 1, edge_weight: 3]

  require Logger

  alias CargoShipping.{LocationService, Utils, VoyagePlans, VoyageService}
  alias CargoShipping.CargoBookings.Itinerary

  def find_itineraries(origin, destination, opts) do
    if Keyword.get(opts, :algorithm, :random) == :random do
      find_itineraries_random(origin, destination, opts)
    else
      find_itineraries_libgraph(origin, destination, opts)
    end
  end

  ## Libgraph implementation

  defmodule TransitEdge do
    @moduledoc """
    Represents an edge in a path through a graph,
    describing the route of a cargo.
    """
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    embedded_schema do
      field :from_node, :string
      field :to_node, :string
      field :from_date, :utc_datetime
      field :to_date, :utc_datetime
    end
  end

  defp find_transit_paths_random(origin, destination, _limitations) do
    start_date = DateTime.utc_now()
    voyage_numbers = VoyageService.all_voyage_numbers()
    candidate_count = Enum.random(3..6)

    Enum.map(1..candidate_count, fn _i ->
      vertices =
        LocationService.all_locodes()
        |> List.delete(origin)
        |> List.delete(destination)
        |> random_chunk_of_nodes()

      leg_vertices = [origin] ++ vertices ++ [destination]
      build_transit_path(leg_vertices, start_date, voyage_numbers)
    end)
    |> Enum.reject(fn path -> is_nil(path) end)
  end

  defp build_transit_path(vertices, start_date, voyage_numbers) do
    init_acc = %{
      error: nil,
      voyage_numbers: voyage_numbers,
      date: on_day_after(start_date),
      edges: []
    }

    last_index = Enum.count(vertices) - 2

    final_acc =
      Enum.reduce_while(0..last_index, init_acc, fn j, acc ->
        curr = Enum.at(vertices, j)
        next = Enum.at(vertices, j + 1)
        accumulate_edge(curr, next, acc)
      end)

    case final_acc do
      {:error, reason} ->
        Logger.error("Giving up: #{reason}")
        nil

      %{edges: edges} ->
        Enum.reverse(edges)
    end
  end

  defp accumulate_edge(
         from_node,
         to_node,
         %{voyage_numbers: voyage_numbers, date: date, edges: edges} = acc
       ) do
    from_date = on_day_after(date)
    to_date = on_day_after(from_date)
    next_date = on_day_after(to_date)

    edge = %TransitEdge{
      id: nil,
      from_node: from_node,
      to_node: to_node,
      from_date: from_date,
      to_date: to_date
    }

    edge_id = find_edge_id(edge, voyage_numbers)

    if edge_id do
      {:cont,
       %{
         acc
         | date: next_date,
           edges: [%TransitEdge{edge | id: edge_id} | edges]
       }}
    else
      {:halt, {:error, "no voyage matching #{Utils.from_struct(edge)}"}}
    end
  end

  # TODO: Select a real voyage (or create a new one?),
  # based on from and to.
  defp find_edge_id(_edge, voyage_numbers) do
    Enum.random(voyage_numbers)
  end

  defp random_chunk_of_nodes(all_nodes) do
    longest_chunk = min(Enum.count(all_nodes), 4)
    chunk_size = Enum.random(1..longest_chunk)

    Enum.shuffle(all_nodes)
    |> Enum.take(chunk_size)
  end

  defp on_day_after(dt) do
    # Add between 6 and 18 hours randomly, on 10 minute intervals.
    rand_seconds = Enum.random(36..108) * 600

    dt
    |> Timex.beginning_of_day()
    |> Timex.to_datetime()
    |> DateTime.add(86_400 + rand_seconds, :second)
  end

  defp find_itineraries_random(origin, destination, opts) do
    find_transit_paths_random(origin, destination, opts)
    |> Enum.map(fn path -> %{itinerary: itinerary_from_transit_path(path), cost: 0} end)
  end

  defp itinerary_from_transit_path(vertices) do
    Enum.map(vertices, &leg_from_transit_edge/1) |> Itinerary.new()
  end

  defp leg_from_transit_edge(edge) do
    voyage_id = VoyageService.get_voyage_id_for_number!(edge.id)

    %{
      voyage_id: voyage_id,
      load_location: edge.from_node,
      unload_location: edge.to_node,
      load_time: edge.from_date,
      unload_time: edge.to_date,
      status: :NOT_LOADED
    }
  end

  ## Libgraph implementation

  defmodule Vertex do
    @moduledoc """
    Represents a vertex in a directed graph.
    """
    use Ecto.Schema

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
  end

  defp find_itineraries_libgraph(origin, destination, limitations) do
    earliest_load_time = Keyword.get(limitations, :earliest_departure, ~U[2000-01-01 00:00:00Z])
    latest_unload_time = Keyword.get(limitations, :arrival_deadline, ~U[2049-12-31 23:59:59Z])

    v_origin = %Vertex{
      name: "#{origin}:ORG",
      type: :ORIGIN,
      location: origin,
      time: earliest_load_time
    }

    v_destination = %Vertex{
      name: "#{destination}:DST",
      type: :DESTINATION,
      location: destination,
      time: latest_unload_time
    }

    graph = build_world_graph(v_origin, v_destination, earliest_load_time, latest_unload_time)

    # {:ok, dot} = Graph.Serializers.DOT.serialize(graph)
    # File.write("routes.dot", dot)

    case Keyword.get(limitations, :find, :shortest) do
      :shortest ->
        case find_shortest_path(graph, v_origin, v_destination) do
          nil ->
            []

          path ->
            [%{itinerary: itinerary_from_path(path), cost: 100}]
        end

      :all ->
        find_all_paths(graph, v_origin, v_destination)
        |> Enum.map(fn path -> {path, cost_for_path(graph, path)} end)
        |> Enum.sort(fn {_path_1, cost_1}, {_path_2, cost_2} -> cost_1 <= cost_2 end)
        |> Enum.map(fn {path, cost} ->
          %{itinerary: itinerary_from_path(path), cost: cost}
        end)
    end
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
      leg_from_libgraph_edge(v_depart, v_arrive)
    end)
    |> Itinerary.new()
  end

  defp leg_from_libgraph_edge(v_depart, v_arrive) do
    %{
      voyage_id: v_depart.voyage_id,
      load_location: v_depart.location,
      unload_location: v_arrive.location,
      load_time: v_depart.time,
      unload_time: v_arrive.time,
      status: :NOT_LOADED
    }
  end

  def build_world_graph(v_origin, v_destination, _earliest_load_time, _latest_unload_time) do
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
        earliest_departure = DateTime.add(v_arrive.time, 12 * 3_600, :second)
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

  def internal_voyage_edges(voyage, acc_0) do
    last_index = Enum.count(voyage.schedule_items) - 1

    {edges, _count, _} =
      Enum.reduce(voyage.schedule_items, {acc_0, 0, last_index}, fn leg, acc ->
        internal_leg_edges(voyage, leg, acc)
      end)

    edges
  end

  def internal_leg_edges(voyage, leg, {edges, i, last}) do
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
end

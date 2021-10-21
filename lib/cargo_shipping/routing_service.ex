defmodule CargoShipping.RoutingService do
  @moduledoc """
  A module that builds new routes.
  """
  alias CargoShipping.{LocationService, VoyageService}

  defmodule TransitEdge do
    @moduledoc """
    Represents an edge in a path through a graph,
    describing the route of a cargo.
    """
    use TypedStruct

    typedstruct do
      @typedoc "An edge in a TransitPath"

      field :edge, String.t(), enforce: true
      field :from_node, String.t(), enforce: true
      field :to_node, String.t(), enforce: true
      field :from_date, DateTime.t(), enforce: true
      field :to_date, DateTime.t(), enforce: true
    end
  end

  def find_itineraries(origin, destination, limitations) do
    find_transit_paths(origin, destination, limitations)
    |> Enum.map(fn path ->
      %{id: UUID.uuid4(), legs: Enum.map(path, &leg_from_edge/1)}
    end)
  end

  defp leg_from_edge(edge) do
    voyage_id = VoyageService.get_voyage_id_for_number!(edge.edge)

    %{
      voyage_id: voyage_id,
      load_location: edge.from_node,
      unload_location: edge.to_node,
      load_time: edge.from_date,
      unload_time: edge.to_date
    }
  end

  defp find_transit_paths(origin, destination, _limitations) do
    vertices =
      LocationService.all_locodes()
      |> List.delete(origin)
      |> List.delete(destination)
      |> random_chunk_of_nodes()

    candidate_count = Enum.random(3..6)

    voyage_numbers = VoyageService.all_voyage_numbers()

    Enum.map(1..candidate_count, fn _i ->
      build_transit_path(origin, destination, vertices, voyage_numbers, DateTime.utc_now())
    end)
  end

  def build_transit_path(origin, destination, vertices, voyage_numbers, start_date) do
    first_leg_to = List.first(vertices)
    last_leg_from = List.last(vertices)

    init_acc = %{voyage_numbers: voyage_numbers, date: later_date(start_date), edges: []}
    first_acc = accumulate_edge(origin, first_leg_to, init_acc)

    last_index = Enum.count(vertices) - 2

    next_acc =
      Enum.reduce(0..last_index, first_acc, fn j, acc ->
        curr = Enum.at(vertices, j)
        next = Enum.at(vertices, j + 1)
        accumulate_edge(curr, next, acc)
      end)

    %{edges: edges} = accumulate_edge(last_leg_from, destination, next_acc)
    Enum.reverse(edges)
  end

  defp accumulate_edge(
         from_node,
         to_node,
         %{voyage_numbers: voyage_numbers, date: date, edges: edges} = acc
       ) do
    from_date = later_date(date)
    to_date = later_date(from_date)
    next_date = later_date(to_date)

    %{
      acc
      | date: next_date,
        edges: [
          %TransitEdge{
            edge: get_transit_edge(from_node, to_node, voyage_numbers),
            from_node: from_node,
            to_node: to_node,
            from_date: from_date,
            to_date: to_date
          }
          | edges
        ]
    }
  end

  defp get_transit_edge(_from_node, _to_node, voyage_numbers) do
    Enum.random(voyage_numbers)
  end

  defp random_chunk_of_nodes(all_nodes) do
    total = Enum.count(all_nodes)

    chunk_size =
      if total > 4 do
        Enum.random(1..5)
      else
        total
      end

    Enum.shuffle(all_nodes)
    |> Enum.take(chunk_size)
  end

  defp later_date(dt) do
    rand_seconds = Enum.random(500..1_000) * 60

    dt
    |> Timex.beginning_of_day()
    |> Timex.to_datetime()
    |> DateTime.add(86_400 + rand_seconds, :second)
  end
end

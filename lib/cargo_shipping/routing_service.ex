defmodule CargoShipping.RoutingService do
  @moduledoc """
  A module that builds new routes.
  """
  require Logger

  alias CargoShipping.{LocationService, VoyageService}

  defmodule TransitEdge do
    @moduledoc """
    Represents an edge in a path through a graph,
    describing the route of a cargo.
    """
    use TypedStruct

    typedstruct do
      @typedoc "An edge in a TransitPath"

      field :id, String.t(), enforce: true
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
    voyage_id = VoyageService.get_voyage_id_for_number!(edge.id)

    %{
      voyage_id: voyage_id,
      load_location: edge.from_node,
      unload_location: edge.to_node,
      load_time: edge.from_date,
      unload_time: edge.to_date
    }
  end

  defp find_transit_paths(origin, destination, _limitations) do
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

  def build_transit_path(vertices, start_date, voyage_numbers) do
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
      {:halt, {:error, "no voyage matching #{Map.from_struct(edge)}"}}
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
    rand_seconds = Enum.random(36..108) * 600

    dt
    |> Timex.beginning_of_day()
    |> Timex.to_datetime()
    |> DateTime.add(86_400 + rand_seconds, :second)
  end
end

defmodule CargoShipping.VoyageService do
  @moduledoc """
  Cached voyage identifiers.
  """
  use Agent

  alias CargoShipping.VoyagePlans

  def start_link(_) do
    Agent.start_link(&load_voyages/0, name: __MODULE__)
  end

  def update_cache() do
    Agent.update(__MODULE__, fn _state -> load_voyages() end)
  end

  def all_voyage_numbers() do
    Agent.get(__MODULE__, & &1)
    |> Enum.map(fn %{voyage_number: voyage_number} -> voyage_number end)
  end

  def get_voyage_number_for_id!(nil), do: nil

  def get_voyage_number_for_id!(id) do
    Agent.get(__MODULE__, & &1)
    |> Enum.find(fn %{id: voyage_id} -> voyage_id == id end)
    |> case do
      nil -> nil
      %{voyage_number: voyage_number} -> voyage_number
    end
  end

  def voyage_id_exists?(id), do: !is_nil(get_voyage_number_for_id!(id))

  def get_voyage_id_for_number!(nil), do: nil

  def get_voyage_id_for_number!(number) do
    Agent.get(__MODULE__, & &1)
    |> Enum.find(fn %{voyage_number: voyage_number} -> voyage_number == number end)
    |> case do
      nil -> nil
      %{id: voyage_id} -> voyage_id
    end
  end

  def voyage_number_exists?(number), do: !is_nil(get_voyage_id_for_number!(number))

  def find_departure_from(id, location) do
    find_movement_by_location(id, location, :departure_location)
  end

  def find_arrival_at(id, location) do
    find_movement_by_location(id, location, :arrival_location)
  end

  def find_movement_by_location(id, location, key) do
    Agent.get(__MODULE__, & &1)
    |> Enum.find(fn %{id: voyage_id} -> voyage_id == id end)
    |> case do
      nil ->
        nil

      %{schedule_items: items} = voyage ->
        case Enum.find(items, fn item -> Map.get(item, key, "_") == location end) do
          nil -> nil
          movement -> %{voyage: voyage, movement: movement}
        end
    end
  end

  def find_items_satisfying_route_specification(id, route_specification) do
    Agent.get(__MODULE__, & &1)
    |> Enum.find(fn %{id: voyage_id} -> voyage_id == id end)
    |> case do
      nil ->
        {:error, :voyage_id, "is invalid"}

      %{voyage_number: voyage_number, schedule_items: items} ->
        origin_index =
          Enum.find_index(items, fn %{departure_location: location} ->
            location == route_specification.origin
          end)

        destination_index =
          Enum.find_index(items, fn %{arrival_location: location} ->
            location == route_specification.destination
          end)

        cond do
          is_nil(origin_index) ->
            {:error, :origin, "is not contained in #{voyage_number}"}

          is_nil(destination_index) ->
            {:error, :destination, "is not contained in #{voyage_number}"}

          destination_index - origin_index < 0 ->
            {:error, :voyage_id, "does not contain this origin-destination pair"}

          true ->
            {:ok,
             items
             |> Enum.drop(origin_index)
             |> Enum.take(destination_index - origin_index + 1)}
        end
    end
  end

  defp load_voyages() do
    VoyagePlans.list_voyages()
  end
end

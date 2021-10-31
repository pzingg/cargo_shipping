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

  def check_leg_in_voyage(id, load_location, unload_location) do
    Agent.get(__MODULE__, & &1)
    |> Enum.find(fn %{id: voyage_id} -> voyage_id == id end)
    |> case do
      nil ->
        {:error, :voyage_id, "is invalid"}

      %{voyage_number: voyage_number, schedule_items: items} ->
        departure_index =
          Enum.find_index(items, fn %{departure_location: location} ->
            location == load_location
          end)

        arrival_index_from_end =
          Enum.reverse(items)
          |> Enum.find_index(fn %{arrival_location: location} ->
            location == unload_location
          end)

        cond do
          is_nil(departure_index) ->
            {:error, :load_location, "is not contained in #{voyage_number}"}

          is_nil(arrival_index_from_end) ->
            {:error, :unload_location, "is not contained in #{voyage_number}"}

          departure_index > Enum.count(items) - arrival_index_from_end - 1 ->
            {:error, :voyage_id, "does not contain this load-unload location pair"}

          true ->
            :ok
        end
    end
  end

  defp load_voyages() do
    VoyagePlans.list_voyages()
  end
end

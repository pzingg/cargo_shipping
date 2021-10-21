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
    |> Enum.map(fn {voyage_number, _voyage_id} -> voyage_number end)
  end

  def get_voyage_number_for_id!(nil), do: nil

  def get_voyage_number_for_id!(id) do
    Agent.get(__MODULE__, & &1)
    |> Enum.find(fn {_voyage_number, voyage_id} -> voyage_id == id end)
    |> case do
      nil -> nil
      {voyage_number, _voyage_id} -> voyage_number
    end
  end

  def get_voyage_id_for_number!(nil), do: nil

  def get_voyage_id_for_number!(number) do
    Agent.get(__MODULE__, & &1)
    |> Enum.find(fn {voyage_number, _voyage_id} -> voyage_number == number end)
    |> case do
      nil -> nil
      {_voyage_number, voyage_id} -> voyage_id
    end
  end

  defp load_voyages() do
    VoyagePlans.list_voyages()
    |> Enum.map(fn %{voyage_number: voyage_number, id: voyage_id} ->
      {voyage_number, voyage_id}
    end)
  end
end

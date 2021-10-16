defmodule CargoShipping.Locations.LocationService do
  @moduledoc """
  Read-only repository for locations.
  """
  use Agent

  alias CargoShipping.Locations.Location

  @locations [
    {"Hongkong", "CHHKG"},
    {"Melbourne", "AUMEL"},
    {"Stockholm", "SESTO"},
    {"Helsinki", "FIHEL"},
    {"Chicago", "USCHI"},
    {"Tokyo", "JPTKO"},
    {"Hamburg", "DEHAM"},
    {"Shanghai", "CNSHA"},
    {"Rotterdam", "NLRTM"},
    {"Goteborg", "SEGOT"},
    {"Hangzhou", "CHHGH"},
    {"New York", "USNYC"},
    {"Dallas", "USDAL"}
  ]

  def start_link(_) do
    Agent.start_link(&load_locations/0, name: __MODULE__)
  end

  def all() do
    Agent.get(__MODULE__, & &1)
  end

  def get!(id) do
    case Enum.find(all(), fn %Location{id: location_id} -> id == location_id end) do
      %Location{} = location ->
        location
      _ ->
        raise Ecto.NoResultsError
    end
  end

  def get_by_port_code(un_locode) when is_binary(un_locode) do
    Enum.find(all(), fn %Location{port_code: port_code} -> port_code == un_locode end)
  end

  def port_code_exists?(un_locode) when is_binary(un_locode) do
    !is_nil(get_by_port_code(un_locode))
  end

  defp load_locations() do
    Enum.map(@locations, fn {name, port_code} ->
      %Location{id: UUID.uuid4(), name: name, port_code: port_code}
    end)
  end
end

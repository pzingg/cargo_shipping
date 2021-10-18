defmodule CargoShipping.Locations.LocationService do
  @moduledoc """
  Read-only repository for locations.
  """
  use Agent

  alias CargoShipping.Locations.Location

  @locations [
    {"_", "Unknown"},
    {"CNHKG", "Hong Kong"},
    {"AUMEL", "Melbourne"},
    {"SESTO", "Stockholm"},
    {"FIHEL", "Helsinki"},
    {"USCHI", "Chicago"},
    {"JPTOK", "Tokyo"},
    {"DEHAM", "Hamburg"},
    {"CNSHA", "Shanghai"},
    {"NLRTM", "Rotterdam"},
    {"SEGOT", "Goteborg"},
    {"CNHGH", "Hangzhou"},
    {"USNYC", "New York"},
    {"USDAL", "Dallas"}
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
    Enum.map(@locations, fn {port_code, name} ->
      %Location{id: UUID.uuid4(), port_code: port_code, name: name}
    end)
  end
end
defmodule CargoShipping.LocationService do
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
    {"JPTYO", "Tokyo"},
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
    |> Enum.reject(fn %Location{port_code: port_code} ->
      port_code == "_"
    end)
  end

  def all_locodes() do
    all()
    |> Enum.map(fn %Location{port_code: port_code} -> port_code end)
  end

  def get!(id) do
    case Enum.find(all(), fn %Location{id: location_id} -> id == location_id end) do
      %Location{} = location ->
        location

      _ ->
        raise Ecto.NoResultsError
    end
  end

  def get_by_locode(nil), do: nil

  def get_by_locode(un_locode) when is_binary(un_locode) do
    Enum.find(all(), fn %Location{port_code: port_code} -> port_code == un_locode end)
  end

  def locode_exists?(nil), do: false

  def locode_exists?(un_locode) when is_binary(un_locode) do
    !is_nil(get_by_locode(un_locode))
  end

  defp load_locations() do
    Enum.map(@locations, fn {port_code, name} -> Location.new(port_code, name) end)
  end
end

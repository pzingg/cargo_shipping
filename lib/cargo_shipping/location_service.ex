defmodule CargoShipping.LocationService do
  @moduledoc """
  Read-only repository for locations.
  """
  import Ecto.Query

  use Agent

  alias CargoShipping.Locations.Location
  alias CargoShippingSchemas.Location, as: Location_

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
    |> Enum.reject(fn %Location_{port_code: port_code} ->
      port_code == "_"
    end)
  end

  def all_except(nil), do: all()

  def all_except(un_locode) when is_binary(un_locode) do
    Agent.get(__MODULE__, & &1)
    |> Enum.reject(fn %Location_{port_code: port_code} ->
      port_code == "_" || port_code == un_locode
    end)
  end

  def all_locodes() do
    all()
    |> Enum.map(fn %Location_{port_code: port_code} -> port_code end)
  end

  def get!(id) do
    case Enum.find(all(), fn %Location_{id: location_id} -> id == location_id end) do
      %Location_{} = location ->
        location

      _ ->
        query = from l in Location, where: l.id == ^id
        raise Ecto.NoResultsError, queryable: query
    end
  end

  def get_by_locode(nil), do: nil

  def get_by_locode(un_locode) when is_binary(un_locode) do
    Enum.find(all(), fn %Location_{port_code: port_code} -> port_code == un_locode end)
  end

  def other_than(un_locode) do
    %Location_{port_code: port_code} = all_except(un_locode) |> Enum.random()
    port_code
  end

  def locode_exists?(nil), do: false

  def locode_exists?(un_locode) when is_binary(un_locode) do
    !is_nil(get_by_locode(un_locode))
  end

  defp load_locations() do
    Enum.map(@locations, fn {port_code, name} -> Location.new(port_code, name) end)
    |> Enum.sort_by(&Map.get(&1, :name))
  end
end

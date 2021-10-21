defmodule CargoShipping.Locations do
  @moduledoc """
  The Locations context.
  """

  import Ecto.Query, warn: false

  alias CargoShipping.LocationService

  ## Location module

  @doc """
  Returns the list of locations.

  ## Examples

      iex> list_locations()
      [%Location{}, ...]

  """
  def list_locations do
    LocationService.all()
  end

  @doc """
  Gets a single location.

  Raises `Ecto.NoResultsError` if the Location does not exist.

  ## Examples

      iex> get_location!(123)
      %Location{}

      iex> get_location!(456)
      ** (Ecto.NoResultsError)

  """
  def get_location!(id), do: LocationService.get!(id)

  def find_location(un_locode) when is_binary(un_locode) do
    LocationService.get_by_port_code(un_locode)
  end

  def location_exists?(un_locode) when is_binary(un_locode) do
    LocationService.port_code_exists?(un_locode)
  end
end

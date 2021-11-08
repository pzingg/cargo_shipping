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
    LocationService.get_by_locode(un_locode)
  end

  def location_exists?(nil), do: false

  def location_exists?(un_locode) when is_binary(un_locode) do
    LocationService.locode_exists?(un_locode)
  end

  def validate_location_code(changeset, field) do
    changeset
    |> Ecto.Changeset.validate_required([field])
    |> validate_location_exists(field)
  end

  def validate_location_exists(changeset, field) do
    if Ecto.Changeset.get_field(changeset, field) |> location_exists?() do
      changeset
    else
      Ecto.Changeset.add_error(changeset, field, "is not a valid location code")
    end
  end
end

defmodule CargoShipping.CargoBookings.RouteSpecification do
  @moduledoc """
  A VALUE OBJECT.

  A RouteSpecification describes where a cargo origin and destination is,
  and the arrival deadline.
  """
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias CargoShipping.Locations

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :origin, :string
    field :destination, :string
    field :earliest_departure, :utc_datetime
    field :arrival_deadline, :utc_datetime
  end

  @doc false
  def changeset(route_specification, attrs) do
    route_specification
    |> cast(attrs, [:origin, :destination, :earliest_departure, :arrival_deadline])
    |> validate_location_code(:origin)
    |> validate_location_code(:destination)
    |> validate_required([:arrival_deadline])
    |> ensure_earliest_departure()
  end

  def validate_location_code(changeset, field) do
    changeset
    |> validate_required([field])
    |> validate_location_exists(field)
  end

  def validate_location_exists(changeset, field) do
    if get_field(changeset, field) |> Locations.location_exists?() do
      changeset
    else
      add_error(changeset, field, "is not a valid location code")
    end
  end

  def ensure_earliest_departure(changeset) do
    if get_field(changeset, :earliest_departure) do
      changeset
    else
      put_change(changeset, :earliest_departure, ~U[2000-01-01 00:00:00Z])
    end
  end

  def debug_route_specification(route_specification) do
    Logger.debug("route")
    Logger.debug("   from #{route_specification.origin} to #{route_specification.destination}")
  end
end

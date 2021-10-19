defmodule CargoShipping.CargoBookings.RouteSpecification do
  @moduledoc """
  A VALUE OBJECT.

  A RouteSpecification describes where a cargo origin and destination is,
  and the arrival deadline.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.Locations

  @primary_key false
  embedded_schema do
    field :origin, :string
    field :destination, :string
    field :arrival_deadline, :utc_datetime
  end

  @doc false
  def changeset(route_specification, attrs) do
    route_specification
    |> cast(attrs, [:origin, :destination, :arrival_deadline])
    |> validate_location_code(:origin)
    |> validate_location_code(:destination)
    |> validate_required([:arrival_deadline])
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
end

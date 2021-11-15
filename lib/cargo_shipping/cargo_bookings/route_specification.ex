defmodule CargoShipping.CargoBookings.RouteSpecification do
  @moduledoc """
  A VALUE OBJECT.

  A RouteSpecification describes where a cargo origin and destination is,
  and the arrival deadline.
  """
  import Ecto.Changeset

  require Logger

  alias CargoShipping.Locations

  defimpl String.Chars, for: CargoShippingSchemas.RouteSpecification do
    use Boundary, classify_to: CargoShipping

    def to_string(route_specification) do
      CargoShipping.CargoBookings.RouteSpecification.string_from(route_specification)
    end
  end

  defimpl Phoenix.Param, for: CargoShippingSchemas.RouteSpecification do
    use Boundary, classify_to: CargoShipping

    def to_param(route_specification) do
      CargoShipping.CargoBookings.RouteSpecification.phoenix_param_from(route_specification)
    end
  end

  def string_from(route_specification) do
    "from #{route_specification.origin} to #{route_specification.destination}"
  end

  def phoenix_param_from(route_specifcation) do
    [
      route_specifcation.origin,
      route_specifcation.destination,
      DateTime.to_unix(route_specifcation.earliest_departure, :millisecond)
      |> Integer.to_string(),
      DateTime.to_unix(route_specifcation.arrival_deadline, :millisecond)
      |> Integer.to_string()
    ]
    |> Enum.join("|")
  end

  @doc false
  def changeset(route_specification, attrs) do
    route_specification
    |> cast(attrs, [:origin, :destination, :earliest_departure, :arrival_deadline])
    |> Locations.validate_location_code(:origin)
    |> Locations.validate_location_code(:destination)
    |> validate_required([:arrival_deadline])
    |> ensure_earliest_departure()
  end

  def ensure_earliest_departure(changeset) do
    if get_field(changeset, :earliest_departure) do
      changeset
    else
      put_change(changeset, :earliest_departure, ~U[2000-01-01 00:00:00Z])
    end
  end

  def debug_route_specification(route_specification, title) do
    Logger.debug(title)
    Logger.debug("  #{string_from(route_specification)}")
  end
end

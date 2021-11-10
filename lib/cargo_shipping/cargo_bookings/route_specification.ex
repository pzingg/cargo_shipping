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
  alias __MODULE__

  defimpl Phoenix.Param, for: RouteSpecification do
    def to_param(route_specifcation) do
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
  end

  defimpl String.Chars, for: RouteSpecification do
    def to_string(route_specification) do
      "from #{route_specification.origin} to #{route_specification.destination}"
    end
  end

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :origin, :string
    field :destination, :string
    field :earliest_departure, :utc_datetime
    field :arrival_deadline, :utc_datetime
  end

  def decode_param(phoenix_param) do
    [origin, destination, departure_millis, arrival_millis] = String.split(phoenix_param, "|")

    {:ok, earliest_departure} =
      String.to_integer(departure_millis) |> DateTime.from_unix(:millisecond)

    {:ok, arrival_deadline} =
      String.to_integer(arrival_millis) |> DateTime.from_unix(:millisecond)

    %RouteSpecification{
      origin: origin,
      destination: destination,
      earliest_departure: earliest_departure,
      arrival_deadline: arrival_deadline
    }
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

  def debug_route_specification(route_specification, title \\ "route") do
    Logger.debug(title)
    Logger.debug("  #{to_string(route_specification)}")
  end
end

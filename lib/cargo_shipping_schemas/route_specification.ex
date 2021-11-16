defmodule CargoShippingSchemas.RouteSpecification do
  @moduledoc """
  A VALUE OBJECT.

  A RouteSpecification describes where a cargo origin and destination is,
  and the arrival deadline.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :origin, :string
    field :destination, :string
    field :earliest_departure, :utc_datetime
    field :arrival_deadline, :utc_datetime
  end

  defimpl Phoenix.Param, for: CargoShippingSchemas.RouteSpecification do
    use Boundary, classify_to: CargoShippingWeb

    def to_param(route_specification) do
      CargoShippingSchemas.RouteSpecification.encode_param(route_specification)
    end
  end

  def encode_param(route_specifcation) do
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

  def decode_param(phoenix_param) do
    [origin, destination, departure_millis, arrival_millis] = String.split(phoenix_param, "|")

    {:ok, earliest_departure} =
      String.to_integer(departure_millis) |> DateTime.from_unix(:millisecond)

    {:ok, arrival_deadline} =
      String.to_integer(arrival_millis) |> DateTime.from_unix(:millisecond)

    %__MODULE__{
      origin: origin,
      destination: destination,
      earliest_departure: earliest_departure,
      arrival_deadline: arrival_deadline
    }
  end
end

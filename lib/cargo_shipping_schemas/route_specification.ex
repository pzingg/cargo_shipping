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

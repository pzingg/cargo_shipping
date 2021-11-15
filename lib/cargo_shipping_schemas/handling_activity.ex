defmodule CargoShippingSchemas.HandlingActivity do
  @moduledoc """
  A VALUE OBJECT.

  A HandlingActivity represents how and where a cargo can be handled,
  and can be used to express predictions about what is expected to
  happen to a cargo in the future.
  """
  use Ecto.Schema

  alias CargoShippingSchemas.HandlingEvent

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :event_type, Ecto.Enum, values: HandlingEvent.event_type_values()
    field :location, :string
    field :voyage_id, Ecto.UUID
  end
end

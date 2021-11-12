defmodule CargoShippingSchemas.CarrierMovement do
  @moduledoc """
  A VALUE OBJECT. A scheduled transit within a voyage.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :previous_arrival_location, :string, virtual: true
    field :departure_location, :string
    field :arrival_location, :string
    field :previous_arrival_time, :utc_datetime, virtual: true
    field :departure_time, :utc_datetime
    field :arrival_time, :utc_datetime
    field :temp_id, :string, virtual: true
    field :delete, :boolean, virtual: true
  end
end

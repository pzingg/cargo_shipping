defmodule CargoShippingSchemas.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  @status_values [:NOT_LOADED, :ONBOARD_CARRIER, :SKIPPED, :COMPLETED, :IN_CUSTOMS, :CLAIMED]

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :status, Ecto.Enum, values: @status_values
    field :voyage_id, Ecto.UUID
    field :load_location, :string
    field :unload_location, :string
    field :actual_load_location, :string
    field :actual_unload_location, :string
    field :load_time, :utc_datetime
    field :unload_time, :utc_datetime
  end

  def status_values, do: @status_values
end

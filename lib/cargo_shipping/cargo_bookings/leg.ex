defmodule CargoShipping.CargoBookings.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @status_values [:NOT_LOADED, :SKIPPED, :ONBOARD_CARRIER, :COMPLETED, :CLAIMED]

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :status, Ecto.Enum, values: @status_values
    field :voyage_id, Ecto.UUID
    field :load_location, :string
    field :unload_location, :string
    field :load_time, :utc_datetime
    field :unload_time, :utc_datetime
  end

  @cast_fields [
    :status,
    :voyage_id,
    :load_location,
    :unload_location,
    :load_time,
    :unload_time
  ]

  @required_fields [
    :voyage_id,
    :load_location,
    :unload_location,
    :load_time,
    :unload_time
  ]

  @doc false
  def changeset(leg, attrs) do
    leg
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> ensure_status()
    |> validate_inclusion(:status, @status_values)
  end

  defp ensure_status(changeset) do
    case get_field(changeset, :status) do
      nil -> put_change(changeset, :status, :NOT_LOADED)
      _status -> changeset
    end
  end
end

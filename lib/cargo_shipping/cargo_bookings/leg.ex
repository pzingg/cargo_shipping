defmodule CargoShipping.CargoBookings.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @status_values [:NOT_LOADED, :ONBOARD, :COMPLETED, :SKIPPED]

  embedded_schema do
    field :status, Ecto.Enum, values: @status_values
    field :voyage_id, Ecto.UUID
    field :load_location, :string
    field :unload_location, :string
    field :load_time, :utc_datetime
    field :unload_time, :utc_datetime
  end

  @doc false
  def changeset(leg, attrs) do
    leg
    |> cast(attrs, [
      :status,
      :voyage_id,
      :load_location,
      :unload_location,
      :load_time,
      :unload_time
    ])
    |> validate_required([:voyage_id, :load_time, :unload_time])
    |> validate_status()
  end

  def validate_status(changeset) do
    if get_field(changeset, :status) do
      changeset
      |> validate_inclusion(:status, @status_values)
    else
      changeset
      |> put_change(:status, :NOT_LOADED)
    end
  end
end

defmodule CargoShipping.CargoBookings.HandlingActivity do
  @moduledoc """
  A VALUE OBJECT.

  A HandlingActivity represents how and where a cargo can be handled,
  and can be used to express predictions about what is expected to
  happen to a cargo in the future.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @event_type_values [:LOAD, :UNLOAD, :RECEIVE, :CLAIM, :CUSTOMS]

  embedded_schema do
    field :event_type, Ecto.Enum, values: @event_type_values
    field :location, :string
    field :voyage_id, Ecto.UUID
  end

  @doc false
  def changeset(handling_activity, attrs) do
    handling_activity
    |> cast(attrs, [:event_type, :location, :voyage_id])
    |> validate_required([:event_type, :location, :voyage_id])
    |> validate_inclusion(:event_type, @event_type_values)
  end
end

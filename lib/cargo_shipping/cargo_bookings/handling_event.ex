defmodule CargoShipping.CargoBookings.HandlingEvent do
  @moduledoc """
  The root of the HandlingEvents AGGREGATE.

  A HandlingEvent is used to register the event when, for instance,
  a cargo is unloaded from a carrier at some location at a given time.

  The HandlingEvents are sent from different Incident Logging Applications
  some time after the event occurred and contain information about the
  `tracking_id`, `location`, timestamp of the completion of the event,
  and possibly, if applicable a `voyage`.

  HandlingEvents could contain information about a `voyage` and if so,
  the event type must be either `:LOAD` or `:UNLOAD`.

  All other events must be of `:RECEIVE`, `:CLAIM` or `:CUSTOMS`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.CargoBookings.Cargo

  @event_type_values [:LOAD, :UNLOAD, :RECEIVE, :CLAIM, :CUSTOMS]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "handling_events" do
    field :event_type, Ecto.Enum, values: @event_type_values
    field :voyage_id, Ecto.UUID
    field :location, :string
    field :completed_at, :utc_datetime
    field :registered_at, :utc_datetime

    belongs_to :cargo, Cargo

    timestamps()
  end


  @cast_fields [:event_type, :voyage_id, :location, :completed_at, :registered_at]
  @required_fields [:event_type, :location, :completed_at, :registered_at]

  @doc false
  def changeset(handling_event, attrs) do
    handling_event
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:event_type, @event_type_values)
  end
end

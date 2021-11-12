defmodule CargoShippingSchemas.HandlingEvent do
  @moduledoc """
  The root of the HandlingEvent AGGREGATE.

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

  @event_type_values [:RECEIVE, :LOAD, :UNLOAD, :CUSTOMS, :CLAIM]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "handling_events" do
    field :event_type, Ecto.Enum, values: @event_type_values
    field :voyage_id, Ecto.UUID
    field :location, :string
    field :completed_at, :utc_datetime
    field :voyage_number, :string, virtual: true
    field :tracking_id, :string, virtual: true

    belongs_to :cargo, Cargo

    timestamps(inserted_at: :registered_at, updated_at: false)
  end

  def event_type_values(), do: @event_type_values
end

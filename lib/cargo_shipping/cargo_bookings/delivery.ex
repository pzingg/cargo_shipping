defmodule CargoShipping.CargoBookings.Delivery do
  @moduledoc """
  A VALUE OBJECT.

  The actual transportation of the cargo, as opposed to
  the customer requirement (RouteSpecification) and the plan (Itinerary).
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.CargoBookings.HandlingActivity

  @transport_status_values [:NOT_RECEIVED, :IN_PORT, :ONBOARD_CARRIER, :CLAIMED, :UNKNOWN]
  @routing_status_values [:NOT_ROUTED, :ROUTED, :MISROUTED]

  embedded_schema do
    field :transport_status, Ecto.Enum, values: @transport_status_values
    field :last_known_location, :string
    field :current_voyage_id, Ecto.UUID
    field :misdirected?, :boolean
    field :eta, :utc_datetime
    field :unloaded_at_destination?, :boolean
    field :routing_status, Ecto.Enum, values: @routing_status_values
    field :calculated_at, :utc_datetime
    field :last_event_id, Ecto.UUID

    embeds_one :next_expected_activity, HandlingActivity, on_replace: :delete
  end

  @cast_fields [
    :transport_status,
    :last_known_location,
    :current_voyage_id,
    :misdirected?,
    :eta,
    :unloaded_at_destination?,
    :routing_status,
    :calculated_at,
    :last_event_id
  ]
  @required_fields [
    :transport_status,
    :last_known_location,
    :current_voyage_id,
    :misdirected?,
    :eta,
    :unloaded_at_destination?,
    :routing_status,
    :calculated_at,
    :last_event_id
  ]

  @doc false
  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:transport_status, @transport_status_values)
    |> validate_inclusion(:routing_status, @routing_status_values)
    |> cast_embed(:next_expected_activity, with: &HandlingActivity.changeset/2)
  end
end

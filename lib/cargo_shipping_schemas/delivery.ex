defmodule CargoShippingSchemas.Delivery do
  @moduledoc """
  A VALUE OBJECT.

  The actual transportation of the cargo, as opposed to
  the customer requirement (RouteSpecification) and the plan (Itinerary).
  """
  use Ecto.Schema

  alias CargoShippingSchemas.{HandlingActivity, HandlingEvent}

  @transport_status_values [:NOT_RECEIVED, :IN_PORT, :ONBOARD_CARRIER, :CLAIMED, :UNKNOWN]
  @routing_status_values [:NOT_ROUTED, :ROUTED, :MISROUTED]

  @primary_key false
  embedded_schema do
    field :transport_status, Ecto.Enum, values: @transport_status_values
    field :routing_status, Ecto.Enum, values: @routing_status_values
    field :current_voyage_id, Ecto.UUID
    field :last_event_id, Ecto.UUID
    field :last_known_location, :string
    field :last_event_type, Ecto.Enum, values: HandlingEvent.event_type_values()
    field :misdirected?, :boolean
    field :unloaded_at_destination?, :boolean
    field :eta, :utc_datetime
    field :calculated_at, :utc_datetime

    embeds_one :next_expected_activity, HandlingActivity, on_replace: :delete
  end

  def transport_status_values(), do: @transport_status_values
  def routing_status_values(), do: @routing_status_values
end

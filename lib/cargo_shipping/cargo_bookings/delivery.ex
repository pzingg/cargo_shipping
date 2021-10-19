defmodule CargoShipping.CargoBookings.Delivery do
  @moduledoc """
  A VALUE OBJECT.

  The actual transportation of the cargo, as opposed to
  the customer requirement (RouteSpecification) and the plan (Itinerary).
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.CargoBookings.{HandlingActivity, Itinerary}

  @transport_status_values [:NOT_RECEIVED, :IN_PORT, :ONBOARD_CARRIER, :CLAIMED, :UNKNOWN]
  @routing_status_values [:NOT_ROUTED, :ROUTED, :MISROUTED]
  @eta_unknown nil

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
    :misdirected?,
    :unloaded_at_destination?,
    :routing_status,
    :calculated_at
  ]

  @doc false
  # def changeset(delivery, attrs) when map_size(attrs) == 0 do
  #  delivery
  #  |> cast(%{}, @cast_fields)
  # end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:transport_status, @transport_status_values)
    |> validate_inclusion(:routing_status, @routing_status_values)
    |> cast_embed(:next_expected_activity, with: &HandlingActivity.changeset/2)
  end

  def new_calculated_changeset(route_specification, itinerary, last_event) do
    last_event_id =
      case last_event do
        nil ->
          nil

        event ->
          event.id
      end

    transport_status = calculate_transport_status(last_event)
    routing_status = calculate_routing_status(itinerary, route_specification)
    misdirected = calculate_misdirection_status(itinerary, last_event)
    on_track = on_track?(routing_status, misdirected)

    %{
      calculated_at: DateTime.utc_now(),
      last_event_id: last_event_id,
      misdirected?: misdirected,
      routing_status: routing_status,
      transport_status: transport_status,
      eta: calculate_eta(itinerary, on_track),
      last_known_location: calculate_last_known_location(last_event),
      current_voyage_id: calculate_current_voyage(transport_status, last_event),
      next_expected_activity:
        calculate_next_expected_activity(route_specification, itinerary, last_event, on_track),
      unloaded_at_destination?: calculate_unloaded_at_destination(route_specification, last_event)
    }
  end

  def update_on_routing(nil, route_specification, itinerary) do
    new_calculated_changeset(route_specification, itinerary, nil)
  end

  def update_on_routing(delivery, route_specification, itinerary) do
    last_event =
      case delivery.last_event_id do
        nil ->
          nil

        event_id ->
          CargoShipping.CargoBookings.get_handling_event!(event_id)
      end

    new_calculated_changeset(route_specification, itinerary, last_event)
  end

  @doc """
  Creates a new delivery snapshot based on the complete handling history of a cargo,
  as well as its route specification and itinerary.
  """
  def derived_from(route_specification, itinerary, handling_history) do
    last_event =
      case handling_history do
        [] -> nil
        [event | _] -> event
      end

    new_calculated_changeset(route_specification, itinerary, last_event)
  end

  def on_track?(:ROUTED, false), do: true
  def on_track?(_routing_status, _misdirected?), do: false

  def calculate_routing_status(nil, _route_specification), do: :NOT_ROUTED

  def calculate_routing_status(itinerary, route_specification) do
    if Itinerary.satisfies?(itinerary, route_specification) do
      :ROUTED
    else
      :MISROUTED
    end
  end

  def calculate_transport_status(nil), do: :NOT_RECEIVED

  def calculate_transport_status(last_event) do
    case last_event.event_type do
      :LOAD -> :ONBOARD_CARRIER
      :UNLOAD -> :IN_PORT
      :RECEIVE -> :IN_PORT
      :CUSTOMS -> :IN_PORT
      :CLAIM -> :CLAIMED
      _ -> :UNKNOWN
    end
  end

  def calculate_last_known_location(nil), do: "_"
  def calculate_last_known_location(last_event), do: last_event.location

  def calculate_current_voyage(_transport_status, nil), do: nil

  def calculate_current_voyage(transport_status, last_event) do
    case transport_status do
      :ONBOARD_CARRIER -> last_event.voyage_id
      _ -> nil
    end
  end

  def calculate_misdirection_status(_itinerary, nil), do: false

  def calculate_misdirection_status(itinerary, last_event) do
    Itinerary.handling_event_expected?(itinerary, last_event)
  end

  def calculate_eta(_itinerary, false), do: @eta_unknown
  def calculate_eta(itinerary, _on_track), do: Itinerary.final_arrival_date(itinerary)

  def calculate_next_expected_activity(_route_specification, _itinerary, _last_event, false),
    do: nil

  def calculate_next_expected_activity(route_specification, _itinerary, nil, _on_track) do
    %{
      event_type: :RECEIVE,
      location: route_specification.origin,
      voyage_id: nil
    }
  end

  def calculate_next_expected_activity(_route_specification, itinerary, last_event, _on_track) do
    case last_event.event_type do
      :LOAD ->
        case Enum.find(itinerary.legs, fn leg -> leg.location == last_event.location end) do
          nil ->
            nil

          found_leg ->
            found_leg
            |> activity_from_leg(:UNLOAD)
        end

      :UNLOAD ->
        case Enum.find_index(itinerary.legs, fn leg -> leg.location == last_event.location end) do
          nil ->
            nil

          i ->
            if Enum.count(itinerary.legs) > i + 1 do
              Enum.at(itinerary.legs, i + 1)
              |> activity_from_leg(:LOAD)
            else
              Enum.at(itinerary.legs, i)
              |> activity_from_leg(:CLAIM)
            end
        end

      :RECIEVE ->
        hd(itinerary.legs)
        |> activity_from_leg(:LOAD)

      _ ->
        nil
    end
  end

  def activity_from_leg(leg, event_type) do
    %{
      event_type: event_type,
      location: leg.location,
      voyage_id: leg.voyage_id
    }
  end

  def calculate_unloaded_at_destination(_route_specification, nil), do: false

  def calculate_unloaded_at_destination(route_specification, last_event) do
    last_event.event_type == :UNLOAD && last_event.location == route_specification.location
  end
end

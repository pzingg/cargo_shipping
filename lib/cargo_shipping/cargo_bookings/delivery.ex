defmodule CargoShipping.CargoBookings.Delivery do
  @moduledoc """
  A VALUE OBJECT.

  The actual transportation of the cargo, as opposed to
  the customer requirement (RouteSpecification) and the plan (Itinerary).
  """
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias CargoShipping.{Utils, VoyageService}
  alias CargoShipping.CargoBookings.{Accessors, HandlingActivity, Itinerary}

  @eta_unknown nil

  @cast_fields [
    :transport_status,
    :routing_status,
    :current_voyage_id,
    :last_event_id,
    :last_known_location,
    :last_event_type,
    :misdirected?,
    :unloaded_at_destination?,
    :eta,
    :calculated_at
  ]
  @required_fields [
    :transport_status,
    :routing_status,
    :misdirected?,
    :unloaded_at_destination?,
    :calculated_at
  ]

  defimpl String.Chars, for: CargoShippingSchemas.Delivery do
    use Boundary, classify_to: CargoShipping

    def to_string(delivery) do
      CargoShipping.CargoBookings.Delivery.string_from(delivery)
    end
  end

  def string_from(delivery) do
    misdirect =
      if delivery.misdirected? do
        " MISDIRECTED"
      else
        ""
      end

    location =
      cond do
        !is_nil(delivery.current_voyage_id) ->
          voyage_number = VoyageService.get_voyage_number_for_id(delivery.current_voyage_id)

          " from #{delivery.last_known_location} on voyage #{voyage_number}"

        !is_nil(delivery.last_known_location) ->
          " at #{delivery.last_known_location}"

        true ->
          ""
      end

    "#{delivery.routing_status} #{delivery.transport_status}#{misdirect}#{location}"
  end

  def delivery_details(delivery) do
    event =
      if delivery.last_event_id do
        "last event #{delivery.last_event_type} at #{delivery.last_known_location}"
      else
        "no events yet"
      end

    activity =
      if delivery.next_expected_activity do
        "next #{delivery.next_expected_activity.event_type} at #{delivery.next_expected_activity.location}"
      else
        "no expected activity"
      end

    [event, activity]
  end

  def debug_delivery(delivery) do
    Logger.debug("delivery #{string_from(delivery)}")

    for line <- delivery_details(delivery) do
      Logger.debug("  #{line}")
    end
  end

  def not_routed() do
    %{
      transport_status: :NOT_RECEIVED,
      last_known_location: nil,
      current_voyage_id: nil,
      misdirected?: false,
      eta: nil,
      unloaded_at_destination?: false,
      routing_status: :NOT_ROUTED,
      calculated_at: DateTime.utc_now(),
      last_event_id: nil
    }
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(
      :transport_status,
      CargoShippingSchemas.Delivery.transport_status_values()
    )
    |> validate_inclusion(:routing_status, CargoShippingSchemas.Delivery.routing_status_values())
    |> cast_embed(:next_expected_activity, with: &HandlingActivity.changeset/2)
  end

  def last_handling_event(nil), do: nil

  def last_handling_event(delivery) do
    case Utils.get(delivery, :last_event_id) do
      nil ->
        nil

      event_id ->
        CargoShipping.CargoBookings.get_handling_event!(event_id)
    end
  end

  @doc """
  Returns a map with the original :itinerary and an updated :delivery.
  """
  def new_route_params(delivery, route_specification, itinerary) do
    last_event = last_handling_event(delivery)
    recalculated_params(route_specification, itinerary, last_event, false)
  end

  @doc """
  Returns a map with an updated :itinerary item and a new :delivery snapshot based
  on the current routing and delivery information.
  """
  def params_derived_from_routing(delivery, route_specification, itinerary) do
    last_event = last_handling_event(delivery)
    recalculated_params(route_specification, itinerary, last_event, true)
  end

  @doc """
  Returns a map with an updated :itinerary item and a new :delivery snapshot based
  on the complete handling history of a cargo, as well as its route specification and itinerary.
  """
  def params_derived_from_history(route_specification, itinerary, handling_history) do
    # TODO: apply ALL events in history, not just the most recent one.
    last_event =
      case handling_history do
        [] -> nil
        [event | _] -> event
      end

    recalculated_params(route_specification, itinerary, last_event, true)
  end

  defp recalculated_params(route_specification, itinerary, last_event, update_itinerary?) do
    last_event_id =
      if is_nil(last_event) do
        nil
      else
        last_event.id
      end

    routing_status = calculate_routing_status(itinerary, route_specification)
    transport_status = calculate_transport_status(last_event)

    {next_itinerary, misdirected} =
      calculate_misdirection_status(itinerary, last_event, update_itinerary?)

    on_track = on_track?(routing_status, misdirected)

    %{
      itinerary: Utils.from_struct(next_itinerary),
      delivery: %{
        calculated_at: DateTime.utc_now(),
        routing_status: routing_status,
        eta: calculate_eta(itinerary, on_track),
        next_expected_activity:
          calculate_next_expected_activity(route_specification, itinerary, last_event, on_track),
        last_event_id: last_event_id,
        misdirected?: misdirected,
        transport_status: transport_status,
        last_known_location: calculate_last_known_location(last_event),
        last_event_type: calculate_last_event_type(last_event),
        current_voyage_id: calculate_current_voyage(transport_status, last_event),
        unloaded_at_destination?:
          calculate_unloaded_at_destination(route_specification, last_event)
      }
    }
  end

  defp on_track?(:ROUTED, false), do: true
  defp on_track?(_routing_status, _misdirected?), do: false

  defp calculate_routing_status(nil, _route_specification), do: :NOT_ROUTED

  defp calculate_routing_status(itinerary, route_specification) do
    if Accessors.itinerary_satisfies?(itinerary, route_specification) do
      :ROUTED
    else
      :MISROUTED
    end
  end

  defp calculate_transport_status(nil), do: :NOT_RECEIVED

  defp calculate_transport_status(last_event) do
    case last_event.event_type do
      :LOAD -> :ONBOARD_CARRIER
      :UNLOAD -> :IN_PORT
      :RECEIVE -> :IN_PORT
      :CUSTOMS -> :IN_PORT
      :CLAIM -> :CLAIMED
      _ -> :UNKNOWN
    end
  end

  defp calculate_last_known_location(nil), do: nil
  defp calculate_last_known_location(last_event), do: last_event.location

  defp calculate_last_event_type(nil), do: nil
  defp calculate_last_event_type(last_event), do: last_event.event_type

  defp calculate_current_voyage(_transport_status, nil), do: nil

  defp calculate_current_voyage(transport_status, last_event) do
    case transport_status do
      :ONBOARD_CARRIER -> last_event.voyage_id
      _ -> nil
    end
  end

  defp calculate_misdirection_status(itinerary, nil, _update_itinerary?), do: {itinerary, false}

  defp calculate_misdirection_status(itinerary, last_event, update_itinerary?) do
    case Itinerary.matches_handling_event(itinerary, last_event,
           update_itinerary: update_itinerary?
         ) do
      {:error, message, updated_itinerary} ->
        Logger.error("misdirection #{last_event.tracking_id} #{message}")
        {updated_itinerary, true}

      {:ok, updated_itinerary} ->
        {updated_itinerary, false}
    end
  end

  defp calculate_eta(_itinerary, false), do: @eta_unknown
  defp calculate_eta(itinerary, _on_track), do: Accessors.itinerary_final_arrival_date(itinerary)

  defp calculate_next_expected_activity(_route_specification, _itinerary, _last_event, false),
    do: nil

  defp calculate_next_expected_activity(route_specification, _itinerary, nil, _on_track) do
    %{
      event_type: :RECEIVE,
      location: route_specification.origin,
      voyage_id: nil
    }
  end

  defp calculate_next_expected_activity(_route_specification, itinerary, last_event, _on_track) do
    case last_event.event_type do
      :RECEIVE ->
        Itinerary.find_leg(:LOAD, itinerary, last_event.location)
        |> activity_from_leg(:LOAD)

      :LOAD ->
        Itinerary.find_leg(:LOAD, itinerary, last_event.location)
        |> activity_from_leg(:UNLOAD)

      :UNLOAD ->
        case Enum.find_index(itinerary.legs, fn leg ->
               Accessors.leg_actual_unload_location(leg) == last_event.location
             end) do
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

      :CUSTOMS ->
        Itinerary.find_leg(:UNLOAD, itinerary, last_event.location)
        |> activity_from_leg(:CLAIM)

      _ ->
        nil
    end
  end

  def activity_from_leg(nil, _event_type), do: nil

  def activity_from_leg(leg, event_type) do
    location =
      case event_type do
        :LOAD -> leg.load_location
        :UNLOAD -> leg.unload_location
        :CLAIM -> leg.unload_location
        _ -> raise RuntimeError, "Unexpected type #{event_type} for next handling activity"
      end

    %{
      event_type: event_type,
      location: location,
      voyage_id: leg.voyage_id
    }
  end

  defp calculate_unloaded_at_destination(_route_specification, nil), do: false

  defp calculate_unloaded_at_destination(route_specification, last_event) do
    last_event.event_type == :UNLOAD && last_event.location == route_specification.destination
  end
end

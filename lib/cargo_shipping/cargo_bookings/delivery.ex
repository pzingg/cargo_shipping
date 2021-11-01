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
  alias CargoShipping.CargoBookings.{HandlingActivity, Itinerary}

  @transport_status_values [:NOT_RECEIVED, :IN_PORT, :ONBOARD_CARRIER, :CLAIMED, :UNKNOWN]
  @routing_status_values [:NOT_ROUTED, :ROUTED, :MISROUTED]
  @eta_unknown nil

  @primary_key false
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
    :misdirected?,
    :unloaded_at_destination?,
    :routing_status,
    :calculated_at
  ]

  def debug_delivery(delivery) do
    misdirect =
      if delivery.misdirected? do
        " MISDIRECTED"
      else
        ""
      end

    Logger.debug("delivery #{delivery.routing_status} #{delivery.transport_status}#{misdirect}")

    if delivery.current_voyage_id do
      voyage_number =
        VoyageService.get_voyage_number_for_id!(delivery.current_voyage_id)
        |> String.pad_trailing(6)

      Logger.debug("  on voyage #{voyage_number} from #{delivery.last_known_location}")
    else
      if delivery.last_known_location != "_" do
        Logger.debug("  at #{delivery.last_known_location}")
      end
    end

    if delivery.last_event_id do
      last_event = CargoShipping.CargoBookings.get_handling_event!(delivery.last_event_id)
      Logger.debug("  last event #{last_event.event_type} at #{last_event.location}")
    else
      Logger.debug("  no events yet")
    end

    if delivery.next_expected_activity do
      Logger.debug(
        "  next #{delivery.next_expected_activity.event_type} at #{delivery.next_expected_activity.location}"
      )
    else
      Logger.debug("  no expected activity")
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
    |> validate_inclusion(:transport_status, @transport_status_values)
    |> validate_inclusion(:routing_status, @routing_status_values)
    |> cast_embed(:next_expected_activity, with: &HandlingActivity.changeset/2)
  end

  @doc """
  Returns a params map with new itinerary and delivery snapshots based on the current
  routing and delivery information.
  """
  def params_derived_from_routing(nil, route_specification, itinerary) do
    recalculated_params(route_specification, itinerary, nil)
  end

  def params_derived_from_routing(delivery, route_specification, itinerary) do
    last_event =
      case Map.get(delivery, :last_event_id) || Map.get(delivery, "last_event_id") do
        nil ->
          nil

        event_id ->
          CargoShipping.CargoBookings.get_handling_event!(event_id)
      end

    recalculated_params(route_specification, itinerary, last_event)
  end

  @doc """
  Returns a params map with new itinerary and delivery snapshots based on the complete handling
  history of a cargo, as well as its route specification and itinerary.
  """
  def params_derived_from_history(route_specification, itinerary, handling_history) do
    last_event =
      case handling_history do
        [] -> nil
        [event | _] -> event
      end

    recalculated_params(route_specification, itinerary, last_event)
  end

  defp recalculated_params(route_specification, itinerary, last_event) do
    transport_status = calculate_transport_status(last_event)
    routing_status = calculate_routing_status(itinerary, route_specification)
    {next_itinerary, misdirected} = calculate_misdirection_status(itinerary, last_event)
    on_track = on_track?(routing_status, misdirected)

    last_event_id =
      case last_event do
        nil ->
          nil

        event ->
          event.id
      end

    %{
      itinerary: Utils.from_struct(next_itinerary),
      delivery: %{
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
        unloaded_at_destination?:
          calculate_unloaded_at_destination(route_specification, last_event)
      }
    }
  end

  defp on_track?(:ROUTED, false), do: true
  defp on_track?(_routing_status, _misdirected?), do: false

  defp calculate_routing_status(nil, _route_specification), do: :NOT_ROUTED

  defp calculate_routing_status(itinerary, route_specification) do
    if Itinerary.satisfies?(itinerary, route_specification) do
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

  defp calculate_last_known_location(nil), do: "_"
  defp calculate_last_known_location(last_event), do: last_event.location

  defp calculate_current_voyage(_transport_status, nil), do: nil

  defp calculate_current_voyage(transport_status, last_event) do
    case transport_status do
      :ONBOARD_CARRIER -> last_event.voyage_id
      _ -> nil
    end
  end

  defp calculate_misdirection_status(itinerary, nil), do: {itinerary, false}

  defp calculate_misdirection_status(itinerary, last_event) do
    case Itinerary.matches_handling_event(itinerary, last_event) do
      {:error, message, _movement_info} ->
        Logger.error("misdirection #{last_event.tracking_id} " <> message)
        {itinerary, true}

      {:ok, updated_itinerary} ->
        {updated_itinerary, false}
    end
  end

  defp calculate_eta(_itinerary, false), do: @eta_unknown
  defp calculate_eta(itinerary, _on_track), do: Itinerary.final_arrival_date(itinerary)

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
               leg.unload_location == last_event.location
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

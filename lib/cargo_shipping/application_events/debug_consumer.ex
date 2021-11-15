defmodule CargoShipping.ApplicationEvents.DebugConsumer do
  @moduledoc """
  Captures all events and logs them.
  """
  require Logger

  alias CargoShipping.CargoBookings.Accessors

  def handle_event(:cargo_booked, _config, event) do
    # Payload is the cargo
    Logger.info(
      "[cargo_booked] #{event.data.tracking_id} from #{Accessors.cargo_origin(event.data)} to #{Accessors.cargo_destination(event.data)}"
    )
  end

  def handle_event(:cargo_booking_failed, _config, event) do
    # Payload is the error changeset
    tracking_id = Ecto.Changeset.get_field(event.data, :tracking_id, "UNKNOWN")

    Logger.error("[cargo_booking_failed] #{tracking_id} #{inspect(event.data.errors)}")
  end

  def handle_event(:cargo_arrived, _config, event) do
    # Payload is the cargo
    Logger.info(
      "[cargo_arrived] #{event.data.tracking_id} at #{Accessors.cargo_destination(event.data)}"
    )
  end

  def handle_event(:cargo_misdirected, _config, event) do
    # Payload is the cargo
    Logger.error("[cargo_misdirected] #{event.data.tracking_id}")
  end

  def handle_event(:cargo_was_handled, _config, event) do
    # Payload is the handling_event
    Logger.info("[cargo_was_handled] #{to_string(event.data)}")
    Accessors.debug_handling_event(event.data)
  end

  def handle_event(:cargo_handling_rejected, _config, event) do
    # Payload is the error changeset
    tracking_id = Ecto.Changeset.get_field(event.data, :tracking_id)
    Logger.error("[cargo_handling_rejected] #{tracking_id} #{inspect(event.data.errors)}")
  end

  def handle_event(:cargo_delivery_updated, _config, event) do
    # Payload is the cargo
    Logger.info(
      "[cargo_delivery_updated] #{event.data.tracking_id} #{to_string(event.data.delivery)}"
    )

    Accessors.debug_itinerary(event.data.itinerary, "itinerary")
    Accessors.debug_delivery(event.data.delivery)
  end

  def handle_event(:cargo_delivery_update_failed, _config, event) do
    # Payload is the error changeset
    tracking_id = Ecto.Changeset.get_field(event.data, :tracking_id)
    Logger.error("[cargo_delivery_update_failed] #{tracking_id} #{inspect(event.data)}")
  end

  def handle_event(:handling_report_received, _config, event) do
    # Payload is handling report
    Logger.info(
      "[handling_report_received] #{event.data.tracking_id} #{event.data.event_type} at {event.data.location}"
    )
  end

  def handle_event(:handling_report_rejected, _config, event) do
    # Payload is the error changeset
    Logger.error("[handling_report_rejected] #{inspect(event.data)}")
  end
end

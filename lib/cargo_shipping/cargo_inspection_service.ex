defmodule CargoShipping.CargoInspectionService do
  @moduledoc """
  Inspect cargo and send relevant notifications to interested parties,
  for example if a cargo has been misdirected, or unloaded
  at the final destination.
  """
  require Logger

  alias CargoShipping.CargoBookings

  def inspect_cargo(tracking_id) do
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    handling_history = CargoBookings.lookup_handling_history(tracking_id)

    params = CargoBookings.derive_delivery_progress(cargo, handling_history)
    {:ok, inspected_cargo} = CargoBookings.update_cargo(cargo, params)

    if cargo.delivery.misdirected? do
      publish_event(:cargo_misdirected, inspected_cargo)
    end

    if cargo.delivery.unloaded_at_destination? do
      publish_event(:cargo_arrived, inspected_cargo)
    end

    publish_event(:cargo_delivery_updated, inspected_cargo)
  end

  def publish_event(topic, payload) do
    CargoShipping.ApplicationEvents.Producer.publish_event(
      topic,
      "CargoInspectionService",
      payload
    )
  end
end

defmodule CargoShipping.ApplicationEvents.CargoHandledConsumer do
  @moduledoc """
  Captures the `:cargo_was_handled` event, and
  calls the `inspect_cargo` in the CargoInspectionService to
  eventually update the Cargo aggregate.
  """
  require Logger

  alias CargoShipping.CargoInspectionService

  def handle_event(:cargo_was_handled, _config, event) do
    # Payload is the handling_event
    Logger.info("CargoHandled [cargo_was_handled] #{to_string(event.data.tracking_id)}")

    # Respond to the event by updating the delivery status
    CargoInspectionService.inspect_cargo(event.data.tracking_id)
  end
end

defmodule CargoShipping.ApplicationEvents.HandlingEventRegistrationAttemptConsumer do
  @moduledoc """
  Captures the `:handling_report_accepted` event and calls the
  HandlingEventService to register a new handling event.
  """
  require Logger

  alias CargoShipping.{HandlingEventService, Utils}

  def handle_event(:handling_report_accepted, _config, event) do
    # Payload is handling report
    Logger.info(
      "RegistrationAttemptConsumer [handling_report_accepted] #{event.data.tracking_id} #{event.data.event_type} at {event.data.location}"
    )

    # Turn around and create a handling event.
    Utils.from_struct(event.data)
    |> HandlingEventService.register_handling_event()
  end
end

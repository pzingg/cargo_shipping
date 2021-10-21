defmodule CargoShipping.HandlingReportService do
  @moduledoc """
  In case of a valid registration attempt, this service sends an asynchronous message
  with the information to the handling event registration system for proper registration.
  """
  require Logger

  def register_handling_report_attempt({:ok, handling_report}) do
    publish_event(:handling_report_received, handling_report)
  end

  def register_handling_report_attempt({:error, changeset}) do
    publish_event(:handling_report_rejected, changeset)
  end

  def publish_event(topic, payload) do
    CargoShipping.ApplicationEvents.Producer.publish_event(
      topic,
      "HandlingReportService",
      payload
    )
  end
end

defmodule CargoShipping.HandlingReportService do
  @moduledoc """
  In case of a valid registration attempt, this service sends an asynchronous message
  with the information to the handling event registration system for proper registration.
  """
  require Logger

  alias CargoShipping.Utils

  def register_handling_report_attempt({:ok, handling_report}, _params) do
    publish_event(:handling_report_received, Utils.from_struct(handling_report))
  end

  @doc """
  The changeset is a HandlingReport changeset.
  """
  def register_handling_report_attempt({:error, changeset}, params) do
    publish_event(:handling_report_rejected, Map.put(params, :errors, changeset.errors))
  end

  def publish_event(topic, payload) do
    CargoShipping.ApplicationEvents.Producer.publish_event(
      topic,
      "HandlingReportService",
      payload
    )
  end
end

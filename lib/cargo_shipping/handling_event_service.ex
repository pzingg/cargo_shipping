defmodule CargoShipping.HandlingEventService do
  @moduledoc """
  When a handling report is successfully parsed and
  a handling report registration attempt message has
  been received asynchronously, this module is responsible
  for creating a new handling event for the cargo in the report.
  """

  alias CargoShipping.CargoBookings

  @doc """
  """
  def register_handling_event(params) do
    # Store the new handling event, which updates the persistent
    # state of the handling event aggregate.
    case CargoBookings.create_handling_event_from_report(params) do
      {:ok, handling_event} ->
        # Publish an event stating that a cargo has been handled.
        publish_event(:cargo_was_handled, handling_event)
      {:error, changeset} ->
        publish_event(:cargo_handling_rejected, changeset)
    end
  end

  def publish_event(topic, payload) do
    CargoShipping.ApplicationEvents.Producer.publish_event(topic, "HandlingEventService", payload)
  end
end

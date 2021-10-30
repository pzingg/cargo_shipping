defmodule CargoShipping.HandlingEventService do
  @moduledoc """
  When a handling report is successfully parsed and
  a handling report registration attempt message has
  been received asynchronously, this module is responsible
  for creating a new handling event for the cargo in the report.
  """

  alias CargoShipping.{CargoBookings, Utils}

  @doc """
  Store the new handling event, which updates the persistent
  state of the handling event aggregate.
  """
  def register_handling_event(params) do
    CargoBookings.create_handling_event_from_report(params)
  end
end

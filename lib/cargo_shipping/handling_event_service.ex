defmodule CargoShipping.HandlingEventService do
  @moduledoc """
  When a handling report is successfully parsed and
  a handling report registration attempt message has
  been received asynchronously, this module is responsible
  for creating a new handling event for the cargo in the report.
  """
  alias CargoShipping.ApplicationEvents.Producer
  alias CargoShipping.CargoBookings.HandlingEvent
  alias CargoShipping.Infra.Repo

  @doc """
  Creates a handling_event.

  ## Examples

      iex> create_handling_event(cargo, %{field: value})
      {:ok, %HandlingEvent_{}}

      iex> create_handling_event(cargo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_handling_event(cargo, attrs \\ %{}) do
    changeset = HandlingEvent.cargo_changeset(cargo, attrs)
    create_and_publish_handling_event(changeset)
  end

  @doc """
  Store the new handling event, which updates the persistent
  state of the handling event aggregate.
  """
  def register_handling_event(params) do
    # Get handling_report_id if it exists
    {handling_report_id, next_params} = Map.pop(params, :id, nil)
    next_params = Map.put(next_params, :handling_report_id, handling_report_id)

    changeset = HandlingEvent.handling_report_changeset(next_params)

    # Logger.error("reigster_handling_event #{inspect(changeset.changes)}")

    create_and_publish_handling_event(changeset)
  end

  defp create_and_publish_handling_event(changeset) do
    tracking_id = Ecto.Changeset.get_field(changeset, :tracking_id)

    case Repo.insert(changeset) do
      {:ok, handling_event} ->
        # Publish an event stating that a cargo has been handled.
        payload = Map.put(handling_event, :tracking_id, tracking_id)
        publish_event(:cargo_was_handled, payload)
        {:ok, handling_event}

      {:error, changeset} ->
        # Publish an event stating that the event was rejected.
        publish_event(:cargo_handling_rejected, changeset)
        {:error, changeset}
    end
  end

  defp publish_event(topic, payload) do
    Producer.publish_event(topic, "HandlingEventService", payload)
  end
end

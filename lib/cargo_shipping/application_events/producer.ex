defmodule CargoShipping.ApplicationEvents.Producer do
  @moduledoc """
  Asynchronous event publisher.
  """
  use EventBus.EventSource

  @doc """
  Wrapper function to build and notify events.
  """
  def publish_event(topic, source, payload)
      when is_atom(topic) and is_binary(source) do
    params =
      %{
        source: source,
        topic: topic
      }

    event =
      EventBus.EventSource.build(params) do
        payload
      end

    _ = EventBus.notify(event)

    event
  end

  ## EventBus id generator public API

  @doc false
  def unique_id, do: UUID.uuid4()
end

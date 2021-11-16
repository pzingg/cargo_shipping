defmodule CargoShipping.ApplicationEvents.Forwarder do
  @moduledoc """
  A module that forwards EventBus messages to a pid (usually a LiveView
  process)
  """

  @doc false
  def process({config, topic, id}) when is_pid(config) do
    subscriber = {__MODULE__, config}
    send(config, {:app_event, subscriber, topic, id})
    :ok
  end

  def process(_) do
    raise "Forwarder config is not a pid"
  end
end

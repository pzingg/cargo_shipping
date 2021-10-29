defmodule CargoShipping.ApplicationEvents.Forwarder do
  @moduledoc """
  Forwards
  """
  require Logger

  @doc false
  def process({config, topic, id}) when is_pid(config) do
    subscriber = {__MODULE__, config}
    send(config, {:app_event, subscriber, topic, id})
    :ok
  end

  def process({_config, topic, _id}) do
    Logger.error("ApplicationEvents.forwarder #{topic}: config is not a pid")
    raise "Forwarder config is not a pid"
  end
end

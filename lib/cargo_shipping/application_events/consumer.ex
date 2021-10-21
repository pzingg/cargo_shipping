defmodule CargoShipping.ApplicationEvents.Consumer do
  @moduledoc """
  Asynchronous event processors.
  """
  use GenServer

  require Logger

  alias CargoShipping.CargoInspectionService

  ## GenServer public API

  @doc false
  def start_link(arg) do
    init_arg = Keyword.put_new(arg, :name, __MODULE__)
    name = Keyword.fetch!(init_arg, :name)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  ## EventBus public API

  @doc false
  def process(event_shadow) do
    GenServer.cast(__MODULE__, event_shadow)
    :ok
  end

  ## GenServer implementation

  @doc """
  Arguments in the arg keyword list:
    :name (required) - The name with with the GenServer was started.
    :topics (optional, default [".*"]) - A list of regex patterns for the
      topics the GenServer will consume.
    :test_pid (optional, defult nil) - If running under ExUnit, the pid of the ExUnit
      process this test is running under. Needed to give the GenServer process
      access to the SQL sandbox.

  Creates an EventBus subscriber with the name of the server instance
  in the subscriber config, and uses the config as the state.
  """
  @impl true
  def init(arg) do
    name = Keyword.fetch!(arg, :name)
    # See: https://medium.com/genesisblock/elixir-concurrent-testing-architecture-13c5e37374dc
    if parent_pid = Keyword.get(arg, :test_pid, nil) do
      # Repo may not be started, so ignore result.
      _ = Ecto.Adapters.SQL.Sandbox.allow(CoreInterfaceDemo.Repo, parent_pid, self())
    end

    # Create the EventBus subscriber config with the name of the server.
    config = %{name: name}
    subscriber = {__MODULE__, config}
    topics = Keyword.get(arg, :topics, [".*"])
    result = EventBus.subscribe({subscriber, topics})

    Logger.error("Consumer #{name} subscribed to #{inspect(topics)} -> #{inspect(result)}")

    {:ok, config}
  end

  @impl true
  def handle_cast({config, topic, id}, state) do
    event = EventBus.fetch_event({topic, id})

    handle_event(topic, config, event)

    subscriber = {__MODULE__, config}
    EventBus.mark_as_completed({subscriber, topic, id})
    {:noreply, state}
  end

  defp handle_event(:cargo_arrived, config, event) do
    Logger.error("[cargo_arrived]")
  end

  defp handle_event(:cargo_misdirected, config, event) do
    Logger.error("[cargo_rejected]")
  end

  defp handle_event(:cargo_was_handled, config, event) do
    # Payload is the params used to create the event
    Logger.error("[cargo_was_handled] #{inspect(event.data)}")

    CargoInspectionService.inspect_cargo(event.data.tracking_id)
  end

  defp handle_event(:handling_report_received, config, event) do
    Logger.error("[handling_report_received]")
  end

  defp handle_event(:handling_report_rejected, config, event) do
    Logger.error("[handling_report_rejected]")
  end
end

defmodule CargoShipping.ApplicationEvents.Consumer do
  @moduledoc """
  Asynchronous event processors.
  """
  use GenServer

  require Logger

  alias CargoShipping.CargoInspectionService
  alias CargoShipping.CargoBookings.{Cargo, Delivery}

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

  defp handle_event(:cargo_arrived, _config, event) do
    # Payload is the cargo
    Logger.error("[cargo_arrived] #{event.data.tracking_id} at #{Cargo.destination(event.data)}")
  end

  defp handle_event(:cargo_misdirected, _config, event) do
    # Payload is the cargo
    Logger.error("[cargo_misdirected] #{event.data.tracking_id}")
  end

  defp handle_event(:cargo_delivery_updated, _config, event) do
    # Payload is the cargo
    Logger.error("[cargo_delivery_updated] #{event.data.tracking_id}")
    Delivery.debug_delivery(event.data.delivery)
  end

  defp handle_event(:cargo_was_handled, _config, event) do
    # Payload is the handling_event
    Logger.error(
      "[cargo_was_handled] #{event.data.tracking_id} #{event.data.event_type} at #{event.data.location}"
    )

    # Respond to the event by updating the delivery status
    CargoInspectionService.inspect_cargo(event.data.tracking_id)
  end

  defp handle_event(:cargo_handling_rejected, _config, event) do
    # Payload is the (error-containing) params
    Logger.error("[cargo_handling_rejected] #{inspect(event.data.errors)}")
  end

  defp handle_event(:handling_report_received, _config, event) do
    # Payload is handling report
    Logger.error("[handling_report_received] #{event.data.tracking_id} #{event.data.event_type}")
  end

  defp handle_event(:handling_report_rejected, _config, event) do
    # Payload is the (error-containing) params
    Logger.error("[handling_report_rejected] #{inspect(event.data.errors)}")
  end
end

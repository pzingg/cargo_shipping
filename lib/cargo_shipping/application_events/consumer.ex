defmodule CargoShipping.ApplicationEvents.Consumer do
  @moduledoc """
  Asynchronous event consumer. Forwards all application
  events to the `:handle_event` method defined in the Elixir module
  specified as the `:name` start argument.
  """
  use GenServer

  require Logger

  ## GenServer public API

  @doc false
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: name,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc false
  def start_link(init_arg) do
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
    topics = Keyword.get(arg, :topics, ".*") |> List.wrap()
    result = EventBus.subscribe({subscriber, topics})

    Logger.info("Module #{name} was subscribed to #{inspect(topics)} -> #{inspect(result)}")

    {:ok, config}
  end

  @impl true
  def handle_cast({config, topic, id}, %{name: name} = state) do
    event = EventBus.fetch_event({topic, id})

    Kernel.apply(name, :handle_event, [topic, config, event])

    subscriber = {__MODULE__, config}
    EventBus.mark_as_completed({subscriber, topic, id})
    {:noreply, state}
  end
end

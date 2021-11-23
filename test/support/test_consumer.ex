defmodule CargoShipping.ApplicationEvents.TestConsumer do
  @moduledoc """
  Captures all events and waits for them.
  """
  use GenServer

  alias Ecto.Adapters.SQL.Sandbox

  def start(arg \\ []) do
    init_arg = Keyword.put_new(arg, :timeout, 2_000)
    GenServer.start(__MODULE__, init_arg, timeout: Keyword.fetch!(init_arg, :timeout) + 1_000)
  end

  def await_topic(pid, topic) do
    GenServer.call(pid, {:await_topic, topic})
  end

  def process({server_pid, _topic, _id} = event_shadow) do
    GenServer.cast(server_pid, event_shadow)

    :ok
  end

  @impl true
  def init(arg) do
    pid = self()

    if parent_pid = Keyword.get(arg, :test_pid, nil) do
      # Repo may not be started, so ignore result.
      _ = Sandbox.allow(CoreInterfaceDemo.Repo, parent_pid, pid)
    end

    subscriber = {__MODULE__, pid}
    topics = Keyword.get(arg, :topics, ".*") |> List.wrap()
    _result = EventBus.subscribe({subscriber, topics})

    timeout = Keyword.fetch!(arg, :timeout)
    Process.send_after(pid, :timeout, timeout)
    {:ok, %{timeout: timeout, events: [], waiters: []}}
  end

  @impl true
  def handle_call({:await_topic, topic}, from, state) do
    next_waiters = [{topic, from} | state.waiters]
    topic_events = find_topic_events(state.events, topic)
    remaining_waiters = maybe_send_replies(next_waiters, topic_events)
    {:noreply, %{state | waiters: remaining_waiters}}
  end

  @impl true
  def handle_cast({config, topic, id}, state) do
    event = EventBus.fetch_event({topic, id})
    subscriber = {__MODULE__, config}
    EventBus.mark_as_completed({subscriber, topic, id})
    next_events = [event | state.events]
    topic_events = find_topic_events(next_events, topic)
    remaining_waiters = maybe_send_replies(state.waiters, topic_events)
    {:noreply, %{state | events: next_events, waiters: remaining_waiters}}
  end

  @impl true
  def handle_info(:timeout, state) do
    for {_topic, from} <- state.waiters do
      GenServer.reply(from, {:error, :timeout})
    end

    {:noreply, %{state | waiters: []}}
  end

  defp find_topic_events(events, topic) do
    events
    |> Enum.filter(fn event -> event.topic == topic end)
    |> Enum.reverse()
  end

  defp maybe_send_replies(waiters, []), do: waiters

  defp maybe_send_replies(waiters, [first | _] = topic_events) do
    case List.keytake(waiters, first.topic, 0) do
      nil ->
        waiters

      {{_topic, from}, rest} ->
        GenServer.reply(from, {:ok, topic_events})

        maybe_send_replies(rest, topic_events)
    end
  end
end

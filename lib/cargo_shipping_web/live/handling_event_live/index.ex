defmodule CargoShippingWeb.HandlingEventLive.Index do
  @moduledoc false
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      subscribe_to_application_events(__MODULE__, self(), [
        "cargo_was_handled",
        "handling_report_*"
      ])
    end

    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tracking_id = Map.get(params, "tracking_id")

    {cargo, handling_events} =
      if is_nil(tracking_id) do
        {nil, CargoBookings.list_handling_events()}
      else
        {CargoBookings.get_cargo_by_tracking_id!(tracking_id),
         CargoBookings.lookup_handling_history(tracking_id) |> Enum.take(25)}
      end

    {:noreply,
     socket
     |> assign(
       page_title: page_title(tracking_id, socket.assigns.live_action),
       cargo: cargo,
       handling_events: handling_events
     )}
  end

  @impl true
  def handle_info({:app_event, subscriber, topic, id}, socket) do
    event = EventBus.fetch_event({topic, id})
    next_socket = add_event_bulletin(socket, topic, event)
    EventBus.mark_as_completed({subscriber, topic, id})
    {:noreply, next_socket}
  end

  @impl true
  def handle_event("clear-bulletin", %{"id" => bulletin_id}, socket) do
    {:noreply, clear_bulletin(socket, bulletin_id)}
  end

  defp page_title(nil, :index), do: "Recent handling events"
  defp page_title(tracking_id, :index), do: "Handling events for #{tracking_id}"
end

defmodule CargoShippingWeb.HandlingEventLive.Index do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    subscribe_to_application_events(self(), "handling_event_*")
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
       cargo: cargo,
       handling_events: handling_events,
       page_title: page_title(tracking_id)
     )}
  end

  @impl true
  def handle_info({:app_event, subscriber, topic, id}, socket) do
    event = EventBus.fetch_event({topic, id})
    next_socket = add_event_bulletin(socket, topic, event)
    EventBus.mark_as_completed({subscriber, topic})
    {:noreply, next_socket}
  end

  @impl true
  def handle_event("clear-bulletin", %{"id" => bulletin_id}, socket) do
    clear_bulletin(bulletin_id, socket)
  end

  defp page_title(nil), do: "Recent handling events"
  defp page_title(tracking_id), do: "Handling events for #{tracking_id}"
end

defmodule CargoShippingWeb.CargoLive.Index do
  @moduledoc false
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      subscribe_to_application_events(__MODULE__, self(), "cargo_*")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    title = page_title(socket.assigns.live_action)

    {:noreply,
     socket
     |> assign(
       header: title,
       page_title: title,
       cargos: CargoBookings.list_cargos()
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

  defp page_title(:index), do: "All cargos"
end

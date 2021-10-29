defmodule CargoShippingWeb.CargoLive.Index do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    subscribe_to_application_events(self(), "cargo_*")
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:header, "All cargos")
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:cargos, CargoBookings.list_cargos())}
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

  defp page_title(:index), do: "Cargos"
end

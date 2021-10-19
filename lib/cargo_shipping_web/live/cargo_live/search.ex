defmodule CargoShippingWeb.CargoLive.Search do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply,
     socket
     |> assign(:header, "Tracking cargos")
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       cargo: nil,
       handling_events: [],
       tracking_id: "",
       matches: [],
       loading: false
     )}
  end

  @impl true
  def handle_event("search", %{"tracking_id" => tracking_id}, socket) do
    send(self(), {:run_search, tracking_id})

    socket =
      assign(socket,
        tracking_id: tracking_id,
        matches: [],
        loading: true
      )

    {:noreply, socket}
  end

  def handle_event("suggest", %{"tracking_id" => prefix}, socket) do
    matches = CargoBookings.suggest_tracking_ids(prefix)
    socket = assign(socket, matches: matches)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:run_search, tracking_id}, socket) do
    case CargoBookings.get_cargo_by_tracking_id!(tracking_id) do
      [] ->
        socket =
          socket
          |> put_flash(:info, "No cargos matching \"#{tracking_id}\"")
          |> assign(cargo: nil, handling_events: [], loading: false)

        {:noreply, socket}

      cargo ->
        socket =
          assign(socket, cargo: cargo, handling_events: cargo.handling_events, loading: false)

        {:noreply, socket}
    end
  end

  defp page_title(:index), do: "Tracking cargo"
end

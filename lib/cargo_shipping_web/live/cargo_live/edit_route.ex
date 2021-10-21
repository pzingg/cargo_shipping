defmodule CargoShippingWeb.CargoLive.EditRoute do
  use CargoShippingWeb, :live_view

  alias CargoShipping.{CargoBookings, CargoBookingService}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    cargo = CargoBookings.get_cargo!(id)

    itineraries =
      CargoBookingService.possible_routes_for_cargo(cargo)
      |> Enum.with_index(fn itinerary, index -> {itinerary, index + 1} end)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       tracking_id: cargo.tracking_id,
       cargo: cargo,
       route_candidates: itineraries
     )}
  end

  defp page_title(:edit), do: "Select a Route"
end

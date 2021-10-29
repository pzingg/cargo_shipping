defmodule CargoShippingWeb.CargoLive.EditRoute do
  use CargoShippingWeb, :live_view

  alias CargoShipping.{CargoBookings, CargoBookingService}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"tracking_id" => tracking_id}, _uri, socket) do
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)

    itineraries =
      CargoBookingService.possible_routes_for_cargo(cargo)
      |> Enum.with_index(fn itinerary, index -> {itinerary, index + 1} end)

    route_candidates =
      if Enum.empty?(itineraries) do
        nil
      else
        itineraries
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       tracking_id: cargo.tracking_id,
       cargo: cargo,
       route_candidates: route_candidates
     )}
  end

  defp page_title(:edit), do: "Select a Route"
end

defmodule CargoShippingWeb.CargoLive.Show do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings
  alias CargoShipping.CargoBookings.Itinerary
  import CargoShippingWeb.CargoLive.ItineraryComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"tracking_id" => tracking_id}, _uri, socket) do
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id, with_events: true)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       handling_events: cargo.handling_events,
       tracking_id: cargo.tracking_id,
       cargo: cargo,
       revert_destination: Itinerary.final_arrival_location(cargo.itinerary),
       return_to: Routes.cargo_show_path(socket, :show, cargo)
     )}
  end

  @impl true
  def handle_event("revert_destination", _data, socket) do
    cargo = socket.assigns.cargo

    case CargoBookings.update_cargo_for_new_destination(
           cargo,
           socket.assigns.revert_destination,
           cargo.route_specification.arrival_deadline
         ) do
      {:ok, _cargo} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cargo destination updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cargo destination was not updated")}
    end
  end

  defp page_title(:show), do: "Cargo"
end

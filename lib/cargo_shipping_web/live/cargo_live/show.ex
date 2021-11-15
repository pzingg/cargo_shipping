defmodule CargoShippingWeb.CargoLive.Show do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings
  alias CargoShipping.CargoBookings.Accessors

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"tracking_id" => tracking_id}, this_uri, socket) do
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id, with_events: true)
    title = page_title(cargo.tracking_id, socket.assigns.live_action)

    itinerary_data =
      if is_nil(cargo.itinerary) do
        %{
          indexed_legs: [],
          selected_index: -1,
          revert_destination: cargo.route_specification.destination
        }
      else
        %{
          indexed_legs: Enum.with_index(cargo.itinerary.legs),
          selected_index: Accessors.itinerary_last_completed_index(cargo.itinerary),
          revert_destination: Accessors.itinerary_final_arrival_location(cargo.itinerary)
        }
      end

    {:noreply,
     socket
     |> assign(itinerary_data)
     |> assign(
       page_title: title,
       cargo: cargo,
       tracking_id: cargo.tracking_id,
       handling_events: cargo.handling_events,
       back_link_label: title,
       back_link_path: this_uri,
       return_to: Routes.cargo_index_path(socket, :index)
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

  defp page_title(tracking_id, :show), do: "Cargo #{tracking_id}"
end

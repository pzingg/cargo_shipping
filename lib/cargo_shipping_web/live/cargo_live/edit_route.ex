defmodule CargoShippingWeb.CargoLive.EditRoute do
  use CargoShippingWeb, :live_view

  alias CargoShipping.{CargoBookings, CargoBookingService}
  alias CargoShipping.CargoBookings.Accessors

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"tracking_id" => tracking_id}, this_uri, socket) do
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)

    {remaining_route_spec, itineraries, patch_uncompleted_leg?} =
      CargoBookingService.possible_routes_for_cargo(cargo)

    route_candidates =
      Enum.with_index(itineraries)
      |> Enum.map(fn {%{itinerary: itinerary, cost: cost}, index} ->
        %{
          index: index,
          title: "Route candidate #{index + 1}",
          itinerary: itinerary,
          is_internal: cost < 0,
          indexed_legs: Enum.with_index(itinerary.legs)
        }
      end)

    title = page_title(cargo.tracking_id, socket.assigns.live_action)
    completed_legs = Accessors.itinerary_completed_legs(cargo)

    {:noreply,
     socket
     |> assign(
       page_title: title,
       cargo: cargo,
       tracking_id: cargo.tracking_id,
       remaining_route_spec: remaining_route_spec,
       completed_legs: Enum.with_index(completed_legs),
       route_candidates: route_candidates,
       patch_uncompleted_leg?: patch_uncompleted_leg?,
       back_link_label: title,
       back_link_path: this_uri,
       return_to: Routes.cargo_show_path(socket, :show, cargo)
     )}
  end

  @impl true
  @doc """
  Fired by click in stateless RouteFormComponent.
  """
  def handle_event("save", %{"index" => index_str} = _params, socket) do
    with {index, ""} <- Integer.parse(index_str),
         {:ok, selected_itinerary} <- find_itinerary(socket.assigns.route_candidates, index),
         {:ok, _cargo} <-
           CargoBookings.update_cargo_for_new_itinerary(
             socket.assigns.cargo,
             selected_itinerary,
             socket.assigns.patch_uncompleted_leg?
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Cargo assigned to route successfully")
       |> push_redirect(to: socket.assigns.return_to)}
    else
      _ ->
        {:noreply, socket |> put_flash(:error, "Could not assign route")}
    end
  end

  defp find_itinerary(route_candidates, index) do
    case Enum.find(route_candidates, fn %{index: idx} -> idx == index end) do
      nil -> {:error, :not_found}
      %{itinerary: itinerary} -> {:ok, itinerary}
    end
  end

  defp page_title(tracking_id, :edit), do: "Select a route for #{tracking_id}"
end

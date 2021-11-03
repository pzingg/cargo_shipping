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

    {remaining_route_spec, indexed_itineraries, patch_uncompleted_leg?} =
      CargoBookingService.possible_routes_for_cargo(cargo)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       tracking_id: cargo.tracking_id,
       cargo: cargo,
       remaining_route_spec: remaining_route_spec,
       route_candidates: indexed_itineraries,
       patch_uncompleted_leg?: patch_uncompleted_leg?
     )}
  end

  @impl true
  @doc """
  Fired by click in stateless RouteFormComponent.
  """
  def handle_event("save", %{"index" => index} = _params, socket) do
    selected_itinerary = Enum.at(socket.assigns.route_candidates, index - 1)

    case CargoBookings.update_cargo_for_new_itinerary(
           socket.assigns.cargo,
           selected_itinerary,
           socket.assigns.patch_uncompleted_leg?
         ) do
      {:ok, _cargo} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cargo assigned to route successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, socket |> put_flash(:error, "Could not assign route")}
    end
  end

  defp page_title(:edit), do: "Select a Route"
end

defmodule CargoShippingWeb.CargoLive.RouteFormComponent do
  use CargoShippingWeb, :live_component

  require Logger

  alias CargoShipping.CargoBookings
  alias CargoShipping.CargoBookings.Cargo

  @impl true
  def update(%{id: id, index: index} = assigns, socket) do
    changeset =
      %Cargo.EditRoute{id: id}
      |> Cargo.EditRoute.changeset(%{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:title, "Route candidate #{index}")}
  end

  @impl true
  def handle_event("save", _params, socket) do
    case CargoBookings.update_cargo_for_new_itinerary(
           socket.assigns.cargo,
           socket.assigns.itinerary
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
end

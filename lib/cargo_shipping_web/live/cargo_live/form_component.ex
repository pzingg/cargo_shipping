defmodule CargoShippingWeb.CargoLive.FormComponent do
  use CargoShippingWeb, :live_component

  alias CargoShipping.CargoBookings

  @impl true
  def update(%{cargo: cargo} = assigns, socket) do
    changeset = CargoBookings.change_cargo(cargo)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"cargo" => cargo_params}, socket) do
    changeset =
      socket.assigns.cargo
      |> CargoBookings.change_cargo(cargo_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"cargo" => cargo_params}, socket) do
    save_cargo(socket, socket.assigns.action, cargo_params)
  end

  defp save_cargo(socket, :edit, cargo_params) do
    case CargoBookings.update_cargo(socket.assigns.cargo, cargo_params) do
      {:ok, _cargo} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cargo updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_cargo(socket, :new, cargo_params) do
    case CargoBookings.create_cargo(cargo_params) do
      {:ok, _cargo} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cargo created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

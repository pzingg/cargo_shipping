defmodule CargoShippingWeb.CargoLive.EditDestination do
  use CargoShippingWeb, :live_view

  alias Ecto.Changeset
  alias CargoShipping.CargoBookings
  alias CargoShippingWeb.SharedComponents.Datepicker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    cargo = CargoBookings.get_cargo!(id)
    changeset = CargoBookings.change_cargo_destination(cargo)
    arrival_deadline = cargo.route_specification.arrival_deadline

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       action: :edit,
       changeset: changeset,
       cargo: cargo,
       tracking_id: cargo.tracking_id,
       arrival_deadline: arrival_deadline,
       location_options: all_location_options(),
       return_to: Routes.cargo_show_path(socket, :show, cargo)
     )}
  end

  @impl true
  def handle_event("validate", raw_params, socket) do
    params =
      Datepicker.handle_form_change(
        "edit_destination",
        "arrival_deadline",
        raw_params,
        &update_datepicker/2
      )

    changeset =
      socket.assigns.cargo
      |> CargoBookings.change_cargo_destination(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    params =
      Datepicker.handle_form_change(
        "edit_destination",
        "arrival_deadline",
        raw_params,
        &update_datepicker/2
      )

    save_cargo_destination(socket, socket.assigns.action, params)
  end

  def update_datepicker(id, dt) do
    send_update(Datepicker, id: id, selected_date: dt)
  end

  defp save_cargo_destination(
         socket,
         :edit,
         %{"arrival_deadline" => arrival_deadline, "destination" => destination} = params
       ) do
    case CargoBookings.update_cargo_for_new_destination(
           socket.assigns.cargo,
           destination,
           arrival_deadline
         ) do
      {:ok, _cargo} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cargo updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = cargo_changeset} ->
        changeset =
          socket.assigns.cargo
          |> CargoBookings.change_cargo_destination(params)

        error_changeset =
          Enum.reduce(cargo_changeset.errors, changeset, fn {field, error}, acc ->
            Changeset.add_error(acc, field, error)
          end)

        {:noreply, assign(socket, :changeset, error_changeset)}
    end
  end

  defp page_title(:edit), do: "Select New Destination"
end

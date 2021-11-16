defmodule CargoShippingWeb.CargoLive.EditDestination do
  @moduledoc false
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings
  alias CargoShippingWeb.SharedComponents.Datepicker
  alias Ecto.Changeset

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"tracking_id" => tracking_id}, _uri, socket) do
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    changeset = CargoBookings.change_cargo_destination(cargo)
    arrival_deadline = cargo.route_specification.arrival_deadline

    {:noreply,
     socket
     |> assign(
       page_title: page_title(tracking_id, socket.assigns.live_action),
       action: socket.assigns.live_action,
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
      Datepicker.handle_form_change("cargo-destination-form", "edit_destination", raw_params)

    changeset =
      socket.assigns.cargo
      |> CargoBookings.change_cargo_destination(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    params =
      Datepicker.handle_form_change("cargo-destination-form", "edit_destination", raw_params)

    save_cargo_destination(socket, socket.assigns.action, params)
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

  defp page_title(tracking_id, :edit), do: "Select a new destination for #{tracking_id}"
end

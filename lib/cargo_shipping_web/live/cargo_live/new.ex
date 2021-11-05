defmodule CargoShippingWeb.CargoLive.New do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings
  alias CargoShipping.CargoBookings.Cargo
  alias CargoShippingWeb.SharedComponents.Datepicker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(
       page_title: page_title(socket.assigns.live_action),
       location_options: all_location_options(),
       changeset: CargoBookings.change_cargo(%Cargo{}),
       return_to: Routes.cargo_index_path(socket, :index)
     )}
  end

  @impl true
  def handle_event("validate", raw_params, socket) do
    # TODO: Filter the choices for voyage_number and location based
    # on changes to tracking_id and voyage_number.
    # params =
    #  Datepicker.handle_form_change(
    #    "cargo",
    #    "completed_at",
    #    raw_params,
    #    &update_datepicker/2
    #  )

    params = Map.fetch!(raw_params, "cargo")

    changeset =
      CargoBookings.change_cargo(%Cargo{}, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    # params =
    #  Datepicker.handle_form_change(
    #    "cargo",
    #    "completed_at",
    #    raw_params,
    #    &update_datepicker/2
    #  )

    params = Map.fetch!(raw_params, "cargo")

    case CargoBookings.create_cargo(params) do
      {:ok, _cargo} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Cargo was booked successfully."
         )
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def update_datepicker(id, dt) do
    send_update(Datepicker, id: id, selected_date: dt)
  end

  defp page_title(:new), do: "Create new cargo booking"
end

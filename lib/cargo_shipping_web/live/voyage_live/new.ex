defmodule CargoShippingWeb.VoyageLive.New do
  use CargoShippingWeb, :live_view

  alias CargoShipping.VoyagePlans
  alias CargoShipping.VoyagePlans.Voyage
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
       changeset: VoyagePlans.change_voyage(%Voyage{}),
       return_to: Routes.voyage_index_path(socket, :index)
     )}
  end

  @impl true
  def handle_event("validate", raw_params, socket) do
    # params =
    #  Datepicker.handle_form_change(
    #    "voyage",
    #    "completed_at",
    #    raw_params,
    #    &update_datepicker/2
    #  )

    params = Map.fetch!(raw_params, "voyage")

    changeset =
      VoyagePlans.change_voyage(%Voyage{}, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    # params =
    #  Datepicker.handle_form_change(
    #    "voyage",
    #    "completed_at",
    #    raw_params,
    #    &update_datepicker/2
    #  )

    params = Map.fetch!(raw_params, "voyage")

    case VoyagePlans.create_voyage(params) do
      {:ok, _voyage} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Voyage was created successfully."
         )
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def update_datepicker(id, dt) do
    send_update(Datepicker, id: id, selected_date: dt)
  end

  defp page_title(:new), do: "Create a new voyage"
end

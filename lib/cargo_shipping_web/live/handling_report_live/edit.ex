defmodule CargoShippingWeb.HandlingReportLive.Edit do
  use CargoShippingWeb, :live_view

  alias CargoShipping.Reports

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_, _, socket) do
    completed_at = DateTime.utc_now()

    # TODO: Filter the choices for voyage_number and location based
    # on changes to tracking_id and voyage_number.

    {:noreply,
     socket
     |> assign(
       page_title: page_title(socket.assigns.live_action),
       changeset: Reports.change_handling_report(%{completed_at: completed_at}),
       event_type_options: event_type_options(),
       cargo_options: all_cargo_options(),
       voyage_options: all_voyage_options(),
       location_options: all_location_options(),
       completed_at: DateTime.to_date(completed_at),
       return_to: Routes.cargo_search_path(socket, :index)
     )}
  end

  @impl true
  def handle_info({:update_selected_date, _datepicker_id, selected_date}, socket) do
    {:ok, completed_at} = DateTime.new(selected_date, ~T[00:00:00], "Etc/UTC")

    changeset = Ecto.Changeset.put_change(socket.assigns.changeset, :completed_at, completed_at)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"handling_report" => params}, socket) do
    changeset =
      Reports.change_handling_report(params)
      |> Map.put(:action, :validate)

    # TODO: Filter the choices for voyage_number and location based
    # on changes to tracking_id and voyage_number.

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"handling_report" => params}, socket) do
    case Reports.create_handling_report(params) do
      {:ok, _handling_report} ->
        {:noreply,
         socket
         |> put_flash(:info, "Handing report submitted")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp page_title(:new), do: "Submit a Handling Report"
end

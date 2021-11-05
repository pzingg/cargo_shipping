defmodule CargoShippingWeb.HandlingReportLive.New do
  use CargoShippingWeb, :live_view

  alias CargoShipping.Reports
  alias CargoShippingWeb.SharedComponents.Datepicker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # TODO: Filter the choices for voyage_number and location based
    # on changes to tracking_id and voyage_number.
    completed_at = DateTime.utc_now()

    {:noreply,
     socket
     |> assign(
       page_title: page_title(socket.assigns.live_action),
       changeset: Reports.change_handling_report(%{completed_at: completed_at}),
       event_type_options: event_type_options(),
       cargo_options: all_cargo_options(),
       voyage_options: all_voyage_options(),
       location_options: all_location_options(),
       completed_at: completed_at,
       return_to: Routes.handling_event_index_path(socket, :all)
     )}
  end

  @impl true
  def handle_event("validate", raw_params, socket) do
    # TODO: Filter the choices for voyage_number and location based
    # on changes to tracking_id and voyage_number.
    params =
      Datepicker.handle_form_change(
        "handling_report",
        "completed_at",
        raw_params,
        &update_datepicker/2
      )

    changeset =
      Reports.change_handling_report(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    params =
      Datepicker.handle_form_change(
        "handling_report",
        "completed_at",
        raw_params,
        &update_datepicker/2
      )

    case Reports.create_handling_report(params) do
      {:ok, handling_report} ->
        Process.sleep(100)
        received_at = event_time(handling_report, :received_at)

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Handling report was received at #{received_at}. You may need to refresh the handling events page to see the event that the report generated."
         )
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def update_datepicker(id, dt) do
    send_update(Datepicker, id: id, selected_date: dt)
  end

  defp page_title(:new), do: "Submit a handling report"
end

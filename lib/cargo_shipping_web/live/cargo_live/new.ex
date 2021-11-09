defmodule CargoShippingWeb.CargoLive.New do
  use CargoShippingWeb, :live_view

  alias CargoShipping.{CargoBookings, LocationService}
  alias CargoShipping.CargoBookings.Cargo
  alias CargoShippingWeb.SharedComponents.Datepicker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    origin = LocationService.all_locodes() |> Enum.random()
    earliest_departure = DateTime.utc_now()

    new_route_specification = %{
      origin: origin,
      destination: LocationService.other_than(origin),
      earliest_departure: earliest_departure,
      arrival_deadline: DateTime.add(earliest_departure, 14 * 24 * 3600, :second)
    }

    {:noreply,
     socket
     |> assign(
       page_title: page_title(socket.assigns.live_action),
       location_options: all_location_options(),
       changeset:
         CargoBookings.change_cargo(%Cargo{}, %{route_specification: new_route_specification}),
       return_to: Routes.cargo_index_path(socket, :index)
     )}
  end

  @impl true
  def handle_event("validate", raw_params, socket) do
    params = Datepicker.handle_form_change("cargo-form", "cargo", raw_params)

    changeset =
      CargoBookings.change_cargo(%Cargo{}, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    params = Datepicker.handle_form_change("cargo-form", "cargo", raw_params)

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

  defp page_title(:new), do: "Create new cargo booking"
end

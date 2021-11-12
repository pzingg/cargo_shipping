defmodule CargoShippingWeb.VoyageLive.New do
  use CargoShippingWeb, :live_view

  require Logger

  import Ecto.Changeset, only: [get_change: 3, put_embed: 4]

  alias CargoShipping.{LocationService, Utils, VoyagePlans}
  alias CargoShippingSchemas.{CarrierMovement, RouteSpecification, Voyage}
  alias CargoShippingWeb.SharedComponents.Datepicker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Create an initial carrier movement

    item_params =
      case Map.get(params, "route_specification") do
        nil ->
          # Create a carrier movement with a random departure and arrival
          departure_location = LocationService.all_locodes() |> Enum.random()
          departure_time = DateTime.utc_now()

          %{
            departure_location: departure_location,
            departure_time: departure_time,
            arrival_location: LocationService.other_than(departure_location),
            arrival_time: DateTime.add(departure_time, 48 * 3600, :second)
          }

        encoded_route_specification ->
          # Create a carrier movement that will satisfy the route specification
          route_specification = RouteSpecification.decode_param(encoded_route_specification)

          %{
            departure_location: route_specification.origin,
            departure_time: route_specification.earliest_departure,
            arrival_location: route_specification.destination,
            arrival_time: route_specification.arrival_deadline
          }
      end

    item_changeset = new_item_changeset(item_params, nil)

    changeset =
      VoyagePlans.change_voyage(%Voyage{})
      |> put_embed(:schedule_items, [item_changeset], [])

    {:noreply,
     socket
     |> assign(
       page_title: page_title(socket.assigns.live_action),
       location_options: all_location_options(),
       changeset: changeset,
       return_to: Routes.voyage_index_path(socket, :index)
     )}
  end

  @impl true
  def handle_event("add-item", _params, socket) do
    existing_items = Map.get(socket.assigns.changeset.changes, :schedule_items, [])

    last_item = List.last(existing_items)

    {previous_arrival_location, previous_arrival_time} =
      case last_item do
        nil ->
          {nil, DateTime.utc_now()}

        last_changeset ->
          arrival_location = get_change(last_changeset, :arrival_location, nil)
          arrival_time = get_change(last_changeset, :arrival_time, DateTime.utc_now())

          {arrival_location, arrival_time}
      end

    departure_time = DateTime.add(previous_arrival_time, 18 * 3600, :second)

    item_changeset =
      %{
        previous_arrival_location: previous_arrival_location,
        previous_arrival_time: previous_arrival_time,
        departure_location: previous_arrival_location,
        departure_time: departure_time,
        arrival_location: LocationService.other_than(previous_arrival_location),
        arrival_time: DateTime.add(departure_time, 48 * 3600, :second)
      }
      |> new_item_changeset(Utils.get_temp_id())

    changeset =
      socket.assigns.changeset
      |> put_embed(:schedule_items, existing_items ++ [item_changeset], [])

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("remove-item", %{"remove" => remove_id}, socket) do
    items =
      socket.assigns.changeset.changes.schedule_items
      |> Enum.reject(fn %{data: item} -> item.temp_id == remove_id end)

    changeset =
      socket.assigns.changeset
      |> put_embed(:schedule_items, items, [])

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("validate", raw_params, socket) do
    params =
      Datepicker.handle_form_change("voyage-form", "voyage", raw_params)
      |> Map.update("schedule_items", %{}, &update_previous_arrivals/1)

    Logger.error("validate schedule_items-> #{inspect(Map.get(params, "schedule_items"))}")

    changeset =
      VoyagePlans.change_voyage(%Voyage{}, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    params = Datepicker.handle_form_change("voyage-form", "voyage", raw_params)

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

  defp new_item_changeset(params, temp_id) do
    %CarrierMovement{temp_id: temp_id}
    |> VoyagePlans.change_carrier_movement(params)
  end

  # schedule_items is something like:
  # %{
  #   "0" => %{
  #     "departure_time" => "2021-11-17 18:25:26Z",
  #      ...
  #   },
  #   "1" => %{
  #     "departure_time" => "2021-11-17 18:25:26Z",
  #      ...
  #   }
  # }
  defp update_previous_arrivals(schedule_items) do
    {reversed_items, _} =
      Enum.reduce(schedule_items, {[], nil}, fn {key, item}, {acc, previous_item} ->
        next_item =
          if is_nil(previous_item) do
            item
          else
            previous_arrival_location = Map.get(previous_item, "arrival_location", nil)
            previous_arrival_time = Map.get(previous_item, "arrival_time", nil)

            item
            |> Map.put("previous_arrival_location", previous_arrival_location)
            |> Map.put("previous_arrival_time", previous_arrival_time)
          end

        {[{key, next_item} | acc], next_item}
      end)

    Enum.reverse(reversed_items) |> Enum.into(%{})
  end

  defp page_title(:new), do: "Create a new voyage"
end

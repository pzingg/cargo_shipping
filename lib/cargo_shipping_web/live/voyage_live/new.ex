defmodule CargoShippingWeb.VoyageLive.New do
  use CargoShippingWeb, :live_view

  require Logger

  alias CargoShipping.{LocationService, Utils, VoyagePlans}
  alias CargoShipping.VoyagePlans.{CarrierMovement, Voyage}
  alias CargoShippingWeb.SharedComponents.Datepicker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Create an initial carrier movement
    departure_location = LocationService.all_locodes() |> Enum.random()
    item_changeset = new_item_changeset(departure_location, DateTime.utc_now(), nil)

    changeset =
      VoyagePlans.change_voyage(%Voyage{})
      |> Ecto.Changeset.put_embed(:schedule_items, [item_changeset])

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
  # params is something like
  # %{
  #   "voyage" => %{
  #     "schedule_items" => %{
  #       "0" => %{
  #         "departure_time" => "2021-11-17 18:25:26Z"
  #       }
  #     }
  #   }
  # }
  def handle_info(
        {:datepicker, _datepicker_id, %{"voyage" => %{"schedule_items" => items_params}}},
        socket
      ) do
    Logger.error("got datepicker info #{inspect(items_params)}")

    updated_items =
      Map.get(socket.assigns.changeset.changes, :schedule_items, [])
      |> update_schedule_items_from_datepicker(items_params)

    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_embed(:schedule_items, updated_items)

    Logger.error("datepicker -> #{inspect(Utils.errors_on(changeset))}")

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("add-item", _params, socket) do
    existing_items = Map.get(socket.assigns.changeset.changes, :schedule_items, [])

    last_item = List.last(existing_items)

    {last_arrival_location, departure_time} =
      case last_item do
        nil ->
          {nil, DateTime.utc_now()}

        last_changeset ->
          arrival_location = Ecto.Changeset.get_change(last_changeset, :arrival_location)

          arrival_time =
            case Ecto.Changeset.get_change(last_changeset, :arrival_time) do
              nil -> DateTime.utc_now()
              dt -> DateTime.add(dt, 18 * 3600, :second)
            end

          {arrival_location, arrival_time}
      end

    item_changeset =
      new_item_changeset(last_arrival_location, departure_time, Utils.get_temp_id())

    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_embed(:schedule_items, existing_items ++ [item_changeset])

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("remove-item", %{"remove" => remove_id}, socket) do
    items =
      socket.assigns.changeset.changes.schedule_items
      |> Enum.reject(fn %{data: item} -> item.temp_id == remove_id end)

    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_embed(:schedule_items, items)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("validate", raw_params, socket) do
    params = Datepicker.handle_form_change("voyage-form", "voyage", raw_params)

    changeset =
      VoyagePlans.change_voyage(%Voyage{}, params)
      |> Map.put(:action, :validate)

    Logger.error("validate -> #{inspect(Utils.errors_on(changeset))}")

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

  defp new_item_changeset(departure_location, departure_time, temp_id) do
    item_params = CarrierMovement.new_params(departure_location, departure_time)

    %CarrierMovement{temp_id: temp_id}
    |> VoyagePlans.change_carrier_movement(item_params)
  end

  # items_params is something like:
  # %{
  #   "0" => %{
  #     "departure_time" => "2021-11-17 18:25:26Z"
  #   }
  # }
  defp update_schedule_items_from_datepicker(schedule_items, items_params) do
    items_index = Map.keys(items_params) |> List.first()

    fields =
      Map.get(items_params, items_index)
      |> Enum.map(fn {field, value} ->
        {:ok, dt, _offset} = DateTime.from_iso8601(value)
        {String.to_atom(field), dt}
      end)

    item_index = String.to_integer(items_index)

    Enum.with_index(schedule_items, fn item, index ->
      next_item =
        if index == item_index do
          Enum.reduce(fields, item, fn {field, value}, cs ->
            Ecto.Changeset.put_change(cs, field, value)
          end)
        else
          item
        end

      Logger.error("#{inspect(next_item)} at #{index}")
      Map.put(next_item, :action, :validate)
    end)
  end

  defp page_title(:new), do: "Create a new voyage"
end

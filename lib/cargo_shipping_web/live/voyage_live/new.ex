defmodule CargoShippingWeb.VoyageLive.New do
  use CargoShippingWeb, :live_view

  require Logger

  alias CargoShipping.{Utils, VoyagePlans}
  alias CargoShipping.VoyagePlans.{CarrierMovement, Voyage}
  alias CargoShippingWeb.SharedComponents.Datepicker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Create an initial carrier movement
    item_changeset = new_item_changeset(nil, DateTime.utc_now(), nil)

    changeset =
      VoyagePlans.change_voyage(%Voyage{})
      |> update_item_changesets([item_changeset])

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
      |> update_item_changesets(existing_items ++ [item_changeset])

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("remove-item", %{"remove" => remove_id}, socket) do
    items =
      socket.assigns.changeset.changes.schedule_items
      |> Enum.reject(fn %{data: item} -> item.temp_id == remove_id end)

    changeset =
      socket.assigns.changeset
      |> update_item_changesets(items)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @datepicker_fields [
    {"schedule_items", "arrival_time"},
    {"schedule_items", "departure_time"}
  ]

  def handle_event("validate", raw_params, socket) do
    params =
      Datepicker.handle_form_change("voyage-form", "voyage", @datepicker_fields, raw_params)

    changeset =
      VoyagePlans.change_voyage(%Voyage{}, params)
      |> Map.put(:action, :validate)

    Logger.error("validate -> #{inspect(changeset)}")

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", raw_params, socket) do
    params =
      Datepicker.handle_form_change("voyage-form", "voyage", @datepicker_fields, raw_params)

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

  defp new_item_changeset(last_arrival_location, departure_time, temp_id) do
    item_params = CarrierMovement.new_params(last_arrival_location, departure_time)

    %CarrierMovement{temp_id: temp_id}
    |> VoyagePlans.change_carrier_movement(item_params)
  end

  defp update_item_changesets(changeset, items) do
    Ecto.Changeset.put_embed(changeset, :schedule_items, items)
  end

  defp page_title(:new), do: "Create a new voyage"
end

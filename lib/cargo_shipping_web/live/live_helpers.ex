defmodule CargoShippingWeb.LiveHelpers do
  import Phoenix.LiveView.Helpers

  require Logger

  alias CargoShipping.{CargoBookings, VoyagePlans, VoyageService, LocationService}
  alias CargoShipping.CargoBookings.Cargo
  alias CargoShippingSchemas.Bulletin
  alias CargoShippingWeb.Router.Helpers, as: Routes

  @doc """
  Renders a component inside the `Example16Web.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal Example16Web.ProjectLive.FormComponent,
        id: @project.id || :new,
        action: @live_action,
        project: @project,
        return_to: Routes.project_index_path(@socket, :index) %>
  """
  def live_modal(component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    live_component(CargoShippingWeb.ModalComponent, modal_opts)
  end

  @doc """
  Set up assigns at mount time for every live view.
  """
  def default_assigns(socket) do
    Phoenix.LiveView.assign(socket, :bulletins, nil)
  end

  def add_event_bulletin(%{assigns: assigns} = socket, topic, _event \\ nil) do
    bulletin = %Bulletin{id: UUID.uuid4(), level: :info, message: "A #{topic} event happened."}

    case Map.get(assigns, :bulletins) do
      nil ->
        Phoenix.LiveView.assign(socket, :bulletins, [bulletin])

      rest ->
        Phoenix.LiveView.assign(socket, :bulletins, [bulletin | rest])
    end
  end

  def clear_bulletin(%{assigns: assigns} = socket, bulletin_id) do
    case Map.get(assigns, :bulletins) do
      nil ->
        socket

      bulletins ->
        Phoenix.LiveView.assign(
          socket,
          :bulletins,
          Enum.reject(bulletins, fn %{id: id} -> id == bulletin_id end)
        )
    end
  end

  @doc """
  Subscribe to EventBus application event topics. If a live view
  calls this method in its `mount` method, it must implement:

  * a `handle_info` callback with a `msg` argument
    signature of `{:app_event, subscriber, topic, id}`.
  * a `handle_event` callback with an `event` argument
    of "clear-bulletin" and a `params` argument signature
    of `%{"id" => bulletin_id}`.
  """
  def subscribe_to_application_events(module, pid, topics \\ ".*") do
    subscriber = {CargoShipping.ApplicationEvents.Forwarder, pid}
    topics = List.wrap(topics)
    result = EventBus.subscribe({subscriber, topics})

    Logger.info(
      "Forwarder #{module} #{inspect(pid)} subscribed to #{inspect(topics)} -> #{inspect(result)}"
    )

    result
  end

  def location_name(location) do
    LocationService.get_by_locode(location).name
  end

  def event_type_options() do
    [
      {"Cargo received", "RECEIVE"},
      {"Cargo loaded", "LOAD"},
      {"Cargo unloaded", "UNLOAD"},
      {"Cargo in customs", "CUSTOMS"},
      {"Cargo claimed", "CLAIM"}
    ]
  end

  def all_location_options() do
    LocationService.all()
    |> Enum.map(fn %{port_code: port_code, name: name} ->
      # First element is the option label
      # Second element is the option value
      {name, port_code}
    end)
    |> Enum.sort()
  end

  def all_voyage_options() do
    VoyagePlans.list_voyages()
    |> Enum.map(fn voyage ->
      label =
        "#{voyage.voyage_number} from #{voyage_origin(voyage)} to #{voyage_destination(voyage)}"

      {label, voyage.voyage_number}
    end)
    |> Enum.sort()
  end

  def all_cargo_options() do
    CargoBookings.list_cargos()
    |> Enum.map(fn cargo ->
      label = "#{cargo.tracking_id} from #{cargo_origin(cargo)} to #{cargo_destination(cargo)}"
      {label, cargo.tracking_id}
    end)
    |> Enum.sort()
  end

  def event_time(map, key, opts \\ []) do
    case Map.get(map, key) do
      nil ->
        ""

      dt ->
        if Keyword.get(opts, :oneline, false) do
          Timex.format!(dt, "%a %b %d, %Y %H:%M GMT", :strftime)
        else
          Timex.format!(dt, "%H:%M GMT<br>%a %b %d, %Y", :strftime) |> Phoenix.HTML.raw()
        end
    end
  end

  def cargo_origin(cargo) do
    cargo.origin |> location_name()
  end

  def cargo_destination(cargo) do
    Cargo.destination(cargo) |> location_name()
  end

  ## Delivery helpers

  def cargo_last_known_location(cargo) do
    case Cargo.last_known_location(cargo) do
      nil -> "None"
      location -> location_name(location)
    end
  end

  def cargo_routing_status(cargo) do
    case Cargo.routing_status(cargo) do
      :ROUTED -> "Routed"
      :MISROUTED -> "Misrouted"
      :NOT_ROUTED -> "Not routed"
    end
  end

  def cargo_routed?(cargo), do: Cargo.routing_status(cargo) != :NOT_ROUTED

  def cargo_misrouted?(cargo), do: Cargo.routing_status(cargo) == :MISROUTED

  def cargo_misdirected?(cargo), do: Cargo.misdirected?(cargo)

  def cargo_transport_status(cargo) do
    case Cargo.transport_status(cargo) do
      :IN_PORT ->
        "#{cargo.tracking_id} is now in port at #{cargo_last_known_location(cargo)}"

      :ONBOARD_CARRIER ->
        voyage_number = Cargo.current_voyage_number(cargo)
        "#{cargo.tracking_id} is now onboard carrier in voyage #{voyage_number}"

      :CLAIMED ->
        "#{cargo.tracking_id} has been claimed"

      :NOT_RECEIVED ->
        "#{cargo.tracking_id} has not been received"

      _ ->
        "#{cargo.tracking_id} has an unknown status"
    end
  end

  def cargo_next_expected_activity(cargo) do
    activity = Cargo.next_expected_activity(cargo)

    if is_nil(activity) do
      "None"
    else
      voyage_number =
        case activity.voyage_id do
          nil -> "None"
          voyage_id -> VoyageService.get_voyage_number_for_id(voyage_id)
        end

      location = activity.location |> location_name()

      case activity.event_type do
        :LOAD ->
          "Load cargo onto voyage #{voyage_number} in #{location}"

        :UNLOAD ->
          "Unload cargo off of voyage #{voyage_number} in #{location}"

        :RECEIVE ->
          "Receive cargo in #{location}"

        :CLAIM ->
          "Claim cargo in #{location}"

        :CUSTOMS ->
          "Cargo at customs in #{location}"
      end
    end
  end

  ## Itinerary helpers

  def voyage_number_for(leg_or_event) do
    case leg_or_event.voyage_id do
      nil -> "(Missing)"
      voyage_id -> VoyageService.get_voyage_number_for_id(voyage_id)
    end
  end

  def voyage_link_for(leg, socket, back_link_label, back_link_path) do
    case VoyageService.get_voyage_for_id(leg.voyage_id) do
      nil ->
        "(Missing)"

      voyage ->
        live_redirect(voyage.voyage_number,
          to:
            Routes.voyage_show_path(socket, :show, voyage,
              back_link_label: back_link_label,
              back_link_path: back_link_path
            )
        )
    end
  end

  def voyage_origin(voyage) do
    case List.first(voyage.schedule_items) do
      nil -> "_"
      carrier_movement -> carrier_movement.departure_location |> location_name()
    end
  end

  def voyage_origin_time(voyage) do
    case List.first(voyage.schedule_items) do
      nil -> "_"
      carrier_movement -> event_time(carrier_movement, :departure_time)
    end
  end

  def voyage_destination(voyage) do
    case List.last(voyage.schedule_items) do
      nil -> "_"
      carrier_movement -> carrier_movement.arrival_location |> location_name()
    end
  end

  def voyage_destination_time(voyage) do
    case List.last(voyage.schedule_items) do
      nil -> "_"
      carrier_movement -> event_time(carrier_movement, :arrival_time)
    end
  end

  ## HandlingEvent helpers

  def handling_event_expected_text(cargo, handling_event) do
    case CargoBookings.handling_event_expected(cargo, handling_event) do
      {:error, reason} -> reason
      :ok -> "Yes"
    end
  end

  def handling_event_description(handling_event) do
    voyage_number =
      case handling_event.voyage_id do
        nil -> ""
        voyage_id -> VoyageService.get_voyage_number_for_id(voyage_id)
      end

    location = handling_event.location |> location_name()

    case handling_event.event_type do
      :LOAD ->
        "Loaded cargo on voyage #{voyage_number} in #{location}"

      :UNLOAD ->
        "Unloaded cargo off of voyage #{voyage_number} in #{location}"

      :RECEIVE ->
        "Received cargo in #{location}"

      :CLAIM ->
        "Claimed cargo in #{location}"

      :CUSTOMS ->
        "Cleared customs"
    end
  end
end

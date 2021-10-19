defmodule CargoShippingWeb.LiveHelpers do
  import Phoenix.LiveView.Helpers

  alias CargoShipping.CargoBookings
  alias CargoShipping.CargoBookings.Cargo
  alias CargoShipping.VoyagePlans
  alias CargoShipping.Locations.LocationService

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

  def default_assigns(socket) do
    socket
  end

  def location_name(location) do
    LocationService.get_by_port_code(location).name
  end

  def event_time(map, key, default \\ "") do
    case Map.get(map, key) do
      nil -> default
      dt -> Timex.format!(dt, "%a %b %d, %Y %Z", :strftime)
    end
  end

  def cargo_next_expected_activity(cargo) do
    activity = cargo.delivery.next_expected_activity

    if is_nil(activity) do
      "None"
    else
      voyage_number =
        case activity.voyage_id do
          nil -> "None"
          voyage_id -> VoyagePlans.get_voyage_number_for_id!(voyage_id)
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

  def cargo_misdirected?(cargo), do: cargo.delivery.misdirected?

  def cargo_origin(cargo) do
    cargo.origin |> location_name()
  end

  # TODO???
  def cargo_destination(cargo) do
    cargo_final_destination(cargo)
  end

  def cargo_final_destination(cargo) do
    Cargo.final_destination(cargo) |> location_name()
  end

  def cargo_routed(cargo), do: Cargo.routed(cargo)

  def cargo_status_text(cargo) do
    case cargo.delivery.transport_status do
      :IN_PORT ->
        location =
          cargo.delivery.last_known_location
          |> location_name

        "Cargo #{cargo.tracking_id} is now in port at #{location}"

      :ONBOARD_CARRIER ->
        voyage_number =
          cargo.delivery.current_voyage_id
          |> VoyagePlans.get_voyage_number_for_id!()

        "Cargo #{cargo.tracking_id} is now onboard carrier in voyage #{voyage_number}"

      :CLAIMED ->
        "Cargo #{cargo.tracking_id} has been claimed"

      :NOT_RECEIVED ->
        "Cargo #{cargo.tracking_id} has not been received"

      _ ->
        "Cargo #{cargo.tracking_id} has an unknown status"
    end
  end

  def leg_voyage_number(leg) do
    case leg.voyage_id do
      nil -> ""
      voyage_id -> VoyagePlans.get_voyage_number_for_id!(voyage_id)
    end
  end

  def handling_event_expected_text(cargo, handling_event) do
    case CargoBookings.handling_event_expected(cargo, handling_event) do
      :ok -> "Yes"
      {:error, reason} -> reason
    end
  end

  def handling_event_description(handling_event) do
    voyage_number =
      case handling_event.voyage_id do
        nil -> ""
        voyage_id -> VoyagePlans.get_voyage_number_for_id!(voyage_id)
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

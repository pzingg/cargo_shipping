defmodule CargoShipping.CargoBookings.HandlingEvent do
  @moduledoc """
  The root of the HandlingEvents AGGREGATE.

  A HandlingEvent is used to register the event when, for instance,
  a cargo is unloaded from a carrier at some location at a given time.

  The HandlingEvents are sent from different Incident Logging Applications
  some time after the event occurred and contain information about the
  `tracking_id`, `location`, timestamp of the completion of the event,
  and possibly, if applicable a `voyage`.

  HandlingEvents could contain information about a `voyage` and if so,
  the event type must be either `:LOAD` or `:UNLOAD`.

  All other events must be of `:RECEIVE`, `:CLAIM` or `:CUSTOMS`.
  """
  import Ecto.Changeset

  require Logger

  alias CargoShipping.{CargoBookings, LocationService, Utils, VoyageService}
  alias CargoShippingSchemas.HandlingEvent

  @cast_fields [
    :cargo_id,
    :tracking_id,
    :handling_report_id,
    :event_type,
    :version,
    :voyage_id,
    :voyage_number,
    :location,
    :completed_at,
    :registered_at
  ]
  @cargo_id_required_fields [:cargo_id, :event_type, :location, :completed_at]
  @tracking_id_required_fields [:tracking_id, :event_type, :location, :completed_at]

  defimpl String.Chars, for: CargoShippingSchemas.HandlingEvent do
    use Boundary, classify_to: CargoShipping

    def to_string(handling_event) do
      CargoShipping.CargoBookings.HandlingEvent.string_from(handling_event)
    end
  end

  def string_from(handling_event) do
    voyage_number =
      case handling_event.voyage_id do
        nil ->
          ""

        voyage_id ->
          " on voyage " <> VoyageService.get_voyage_number_for_id(voyage_id)
      end

    "#{handling_event.tracking_id} #{handling_event.event_type} at #{handling_event.location}#{voyage_number}"
  end

  @doc false
  def cargo_changeset(cargo, attrs) do
    cargo
    |> set_cargo_id(attrs)
    |> changeset(@cargo_id_required_fields)
  end

  @doc """
  A changeset that looks up the cargo by tracking id and fails if
  it cannot find the cargo, or if the version number does not
  match.
  """
  def handling_report_changeset(attrs), do: changeset(attrs, @tracking_id_required_fields)

  defp changeset(attrs, required_fields) do
    %HandlingEvent{}
    |> cast(attrs, @cast_fields)
    |> validate_required(required_fields)
    |> validate_inclusion(:event_type, HandlingEvent.event_type_values())
    |> validate_location()
    |> validate_voyage_number_or_id()
    |> validate_cargo_fields()
  end

  def validate_location(changeset) do
    changeset
    |> validate_required([:location])
    |> validate_location_exists?()
  end

  def validate_location_exists?(changeset) do
    location = get_change(changeset, :location)

    if LocationService.locode_exists?(location) do
      changeset
    else
      add_error(changeset, :location, "is invalid")
    end
  end

  def validate_voyage_number_or_id(changeset) do
    case get_field(changeset, :event_type) do
      :LOAD ->
        validate_required_voyage_number_or_id(changeset)

      :UNLOAD ->
        validate_required_voyage_number_or_id(changeset)

      _ ->
        changeset
    end
  end

  def validate_required_voyage_number_or_id(changeset) do
    validate_voyage_params(
      changeset,
      get_field(changeset, :voyage_id),
      get_field(changeset, :voyage_number)
    )
  end

  defp validate_voyage_params(changeset, nil, nil) do
    add_error(changeset, :voyage_number, "can't be blank if voyage_id is blank")
  end

  defp validate_voyage_params(changeset, nil, voyage_number) do
    case VoyageService.get_voyage_id_for_number(voyage_number) do
      nil ->
        add_error(changeset, :voyage_number, "is invalid")

      voyage_id ->
        put_change(changeset, :voyage_id, voyage_id)
    end
  end

  defp validate_voyage_params(changeset, voyage_id, _) do
    if VoyageService.voyage_id_exists?(voyage_id) do
      changeset
    else
      add_error(changeset, :voyage_id, "is invalid")
    end
  end

  defp validate_cargo_fields(changeset) do
    tracking_id = get_change(changeset, :tracking_id)
    cargo_id = get_field(changeset, :cargo_id)

    case {is_nil(cargo_id), is_nil(tracking_id)} do
      {false, _} ->
        try do
          cargo = CargoBookings.get_cargo!(cargo_id)
          set_cargo_fields(changeset, cargo)
        rescue
          _ -> add_error(changeset, :cargo_id, "is invalid")
        end

      {true, false} ->
        try do
          cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
          set_cargo_fields(changeset, cargo)
        rescue
          _ ->
            add_error(changeset, :tracking_id, "is invalid")
        end

      _ ->
        add_error(changeset, :cargo_id, "can't be blank")
    end
  end

  def set_cargo_fields(changeset, cargo) do
    version = get_change(changeset, :version)

    next_changeset =
      if is_nil(version) || version == cargo.version do
        changeset
        |> put_change(:version, cargo.version)
      else
        changeset
        |> add_error(:version, "should match current cargo version",
          version: version,
          cargo_version: cargo.version
        )
      end

    next_changeset
    |> put_change(:cargo_id, cargo.id)
    |> put_change(:tracking_id, cargo.tracking_id)
    |> validate_permissible_event_for_cargo(cargo)
  end

  defp validate_permissible_event_for_cargo(changeset, cargo) do
    transport_status = cargo.delivery.transport_status
    event_type = get_change(changeset, :event_type)

    if is_nil(event_type) ||
         permitted_event_for_transport_status?(event_type, transport_status) do
      changeset
    else
      add_error(changeset, :event_type, "is not permitted for #{transport_status}")
    end
  end

  def permitted_event_for_transport_status?(event_type, transport_status) do
    # event_type is one of [:RECEIVE, :LOAD, :UNLOAD, :CUSTOMS, :CLAIM]
    # transport_status is one of [:NOT_RECEIVED, :IN_PORT, :ONBOARD_CARRIER, :CLAIMED, :UNKNOWN]
    case event_type do
      :RECEIVE -> transport_status == :NOT_RECEIVED
      :LOAD -> transport_status != :CLAIMED
      :UNLOAD -> transport_status != :CLAIMED
      :CUSTOMS -> transport_status != :CLAIMED
      :CLAIM -> transport_status != :CLAIMED
    end
  end

  def expected_event_for_transport_status?(event_type, transport_status) do
    # event_type is one of [:RECEIVE, :LOAD, :UNLOAD, :CUSTOMS, :CLAIM]
    # transport_status is one of [:NOT_RECEIVED, :IN_PORT, :ONBOARD_CARRIER, :CLAIMED, :UNKNOWN]
    case event_type do
      :RECEIVE -> transport_status == :NOT_RECEIVED
      :LOAD -> transport_status == :IN_PORT
      :UNLOAD -> transport_status == :ONBOARD_CARRIER
      :CUSTOMS -> transport_status == :IN_PORT
      :CLAIM -> transport_status == :IN_PORT
    end
  end

  ## Utility functions

  def set_cargo_id(cargo, attrs) do
    cargo_id_key =
      if Utils.atom_keys?(attrs) do
        :cargo_id
      else
        "cargo_id"
      end

    attrs
    |> Map.put(cargo_id_key, cargo.id)
  end

  def debug_handling_event(handling_event) do
    Logger.debug("handling_event")
    Logger.debug("   #{string_from(handling_event)}")
  end
end

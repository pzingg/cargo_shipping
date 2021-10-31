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
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias CargoShipping.{CargoBookings, LocationService, VoyageService}
  alias CargoShipping.CargoBookings.Cargo

  @event_type_values [:RECEIVE, :LOAD, :UNLOAD, :CUSTOMS, :CLAIM]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "handling_events" do
    field :event_type, Ecto.Enum, values: @event_type_values
    field :voyage_id, Ecto.UUID
    field :location, :string
    field :completed_at, :utc_datetime
    field :voyage_number, :string, virtual: true
    field :tracking_id, :string, virtual: true

    belongs_to :cargo, Cargo

    timestamps(inserted_at: :registered_at, updated_at: false)
  end

  @cast_fields [
    :cargo_id,
    :tracking_id,
    :event_type,
    :voyage_id,
    :voyage_number,
    :location,
    :completed_at,
    :registered_at
  ]
  @cargo_id_required_fields [:cargo_id, :event_type, :location, :completed_at]
  @tracking_id_required_fields [:event_type, :location, :completed_at]

  @doc false
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_fields)
    |> validate_required(@cargo_id_required_fields)
    |> validate_inclusion(:event_type, @event_type_values)
    |> validate_location()
    |> validate_voyage_number_or_id()
    |> validate_permissible_event_for_cargo()
  end

  def tracking_id_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @cast_fields)
    |> validate_required(@tracking_id_required_fields)
    |> validate_inclusion(:event_type, @event_type_values)
    |> validate_location()
    |> validate_voyage_number_or_id()
    |> validate_permissible_event_for_cargo()
  end

  @doc """
  A changeset that looks up the cargo by tracking id and fails if
  it cannot find the cargo.
  """
  def handling_report_changeset(attrs) do
    case CargoBookings.set_cargo_id_from_tracking_id(attrs) do
      {:ok, event_attrs} ->
        changeset(event_attrs)

      {:error, message} ->
        tracking_id_changeset(attrs)
        |> add_error(:tracking_id, message)
    end
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
    case VoyageService.get_voyage_id_for_number!(voyage_number) do
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

  defp validate_permissible_event_for_cargo(changeset) do
    case check_cargo_fields(changeset) do
      {:error, message} ->
        add_error(changeset, :cargo, message)

      {:ok, cargo} ->
        event_type = get_change(changeset, :event_type)
        transport_status = cargo.delivery.transport_status

        if check_event_type(event_type, transport_status) do
          changeset
        else
          add_error(changeset, :event_type, "is not permitted for #{transport_status}")
        end
    end
  end

  defp check_event_type(event_type, transport_status) do
    case transport_status do
      :NOT_RECEIVED ->
        event_type == :RECEIVE

      :IN_PORT ->
        event_type != :RECEIVE

      :ONBOARD_CARRIER ->
        event_type != :RECEIVE

      :CLAIMED ->
        false

      :UNKNOWN ->
        true
    end
  end

  defp check_cargo_fields(changeset) do
    cargo_id = get_field(changeset, :cargo_id)
    cargo = get_field(changeset, :cargo)

    case {is_nil(cargo), is_nil(cargo_id)} do
      {false, _} ->
        {:ok, cargo}

      {true, true} ->
        {:error, "can't be blank"}

      {true, false} ->
        case CargoBookings.get_cargo!(cargo_id) do
          nil -> {:error, "is invalid"}
          c -> {:ok, c}
        end
    end
  end

  def debug_handling_event(handling_event) do
    voyage_number =
      case handling_event.voyage_id do
        nil ->
          ""

        voyage_id ->
          " on voyage " <> VoyageService.get_voyage_number_for_id!(voyage_id)
      end

    Logger.debug("handling_event")

    Logger.debug(
      "   #{handling_event.tracking_id} #{handling_event.event_type} at #{handling_event.location}#{voyage_number}"
    )
  end
end

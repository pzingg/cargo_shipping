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

  alias CargoShipping.{CargoBookings, LocationService, Utils, VoyageService}
  alias CargoShipping.CargoBookings.Cargo

  @event_type_values [:LOAD, :UNLOAD, :RECEIVE, :CLAIM, :CUSTOMS]

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
    :event_type,
    :voyage_id,
    :voyage_number,
    :location,
    :completed_at,
    :registered_at
  ]
  @required_fields [:cargo_id, :event_type, :location, :completed_at]

  @doc false
  def changeset(handling_event, attrs) do
    handling_event
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_cargo_exists?()
    |> validate_inclusion(:event_type, @event_type_values)
    |> validate_location()
    |> validate_voyage_number_or_id()
  end

  @doc """
  Looks up the cargo by tracking id and fails if
  it cannot find the cargo.
  """
  def handling_report_changeset(attrs) do
    tracking_id_changeset =
      %__MODULE__{}
      |> cast(attrs, [:tracking_id])

    tracking_id = get_change(tracking_id_changeset, :tracking_id)

    case CargoBookings.get_cargo_by_tracking_id!(tracking_id) do
      nil ->
        tracking_id_changeset
        |> add_error(:tracking_id, "is invalid")

      cargo ->
        cargo_id_key =
          if Utils.atom_keys?(attrs) do
            :cargo_id
          else
            "cargo_id"
          end

        event_attrs =
          attrs
          |> Map.put(cargo_id_key, cargo.id)

        %__MODULE__{}
        |> changeset(event_attrs)
    end
  end

  def validate_cargo_exists?(changeset) do
    cargo_id = get_change(changeset, :cargo_id)

    if CargoBookings.get_cargo!(cargo_id) do
      changeset
    else
      changeset
      |> add_error(:cargo_id, "is invalid")
    end
  end

  def validate_cargo_or_id(changeset, %Cargo{id: cargo_id} = _cargo, nil) do
    changeset
    |> put_change(:cargo_id, cargo_id)
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
      changeset
      |> add_error(:location, "is invalid")
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
    changeset
    |> add_error(:voyage_number, "can't be blank if voyage_id is blank")
  end

  defp validate_voyage_params(changeset, nil, voyage_number) do
    case VoyageService.get_voyage_id_for_number!(voyage_number) do
      nil ->
        changeset
        |> add_error(:voyage_number, "is invalid")

      voyage_id ->
        changeset
        |> put_change(:voyage_id, voyage_id)
    end
  end

  defp validate_voyage_params(changeset, voyage_id, _) do
    if VoyageService.voyage_id_exists?(voyage_id) do
      changeset
    else
      changeset
      |> add_error(:voyage_id, "is invalid")
    end
  end
end

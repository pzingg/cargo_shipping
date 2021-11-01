defmodule CargoShipping.Reports.HandlingReport do
  use Ecto.Schema
  import Ecto.Changeset

  alias CargoShipping.{CargoBookings, LocationService, VoyageService}
  alias __MODULE__

  @event_type_values [:RECEIVE, :LOAD, :UNLOAD, :CUSTOMS, :CLAIM]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "handling_reports" do
    field :event_type, Ecto.Enum, values: @event_type_values
    field :tracking_id, :string
    field :voyage_number, :string
    field :location, :string
    field :completed_at, :utc_datetime

    timestamps(inserted_at: :received_at, updated_at: false)
  end

  defimpl String.Chars, for: HandlingReport do
    def to_string(handling_report) do
      voyage_number =
        case handling_report.voyage_number do
          nil -> ""
          "" -> ""
          number -> " on voyage #{number}"
        end

      "#{handling_report.tracking_id} #{handling_report.event_type} at #{handling_report.location}#{voyage_number}"
    end
  end

  @doc false
  def changeset(handling_report, attrs) do
    handling_report
    |> cast(attrs, [:event_type, :tracking_id, :voyage_number, :location, :completed_at])
    |> validate_required([:event_type, :completed_at])
    |> validate_inclusion(:event_type, @event_type_values)
    |> validate_tracking_id()
    |> validate_location()
    |> validate_voyage_number()
    |> validate_tracking_id()
  end

  def validate_tracking_id(changeset) do
    changeset
    |> validate_required([:tracking_id])
    |> validate_cargo_exists?()
  end

  def validate_cargo_exists?(changeset) do
    tracking_id = get_change(changeset, :tracking_id)

    if CargoBookings.cargo_tracking_id_exists?(tracking_id) do
      changeset
    else
      changeset
      |> add_error(:tracking_id, "is invalid")
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
      changeset
      |> add_error(:location, "is invalid")
    end
  end

  def validate_voyage_number(changeset) do
    event_type = get_change(changeset, :event_type)

    case event_type do
      :LOAD ->
        changeset
        |> validate_required([:voyage_number])
        |> validate_voyage_exists?()

      :UNLOAD ->
        changeset
        |> validate_required([:voyage_number])
        |> validate_voyage_exists?()

      _ ->
        changeset
    end
  end

  def validate_voyage_exists?(changeset) do
    voyage_number = get_change(changeset, :voyage_number)

    if VoyageService.voyage_number_exists?(voyage_number) do
      changeset
    else
      changeset
      |> add_error(:voyage_number, "is invalid")
    end
  end
end

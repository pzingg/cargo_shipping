defmodule CargoShipping.Reports.HandlingReport do
  @moduledoc """
  The HandlingReport AGGREGATE.

  HandlingReports are usually created via the REST API.
  When validated, they trigger the asynchronous creation
  of a HandlingEvent.
  """
  import Ecto.Changeset

  alias CargoShipping.{CargoBookings, LocationService, VoyageService}
  alias CargoShippingSchemas.{HandlingEvent, HandlingReport}

  defimpl String.Chars, for: CargoShippingSchemas.HandlingReport do
    use Boundary, classify_to: CargoShipping

    def to_string(handling_report) do
      CargoShipping.Reports.HandlingReport.string_from(handling_report)
    end
  end

  def string_from(handling_report) do
    voyage_number =
      case handling_report.voyage_number do
        nil -> ""
        "" -> ""
        number -> " on voyage #{number}"
      end

    "#{handling_report.tracking_id} #{handling_report.event_type} at #{handling_report.location}#{voyage_number}"
  end

  @doc false
  def changeset(attrs) do
    %HandlingReport{}
    |> cast(attrs, [:event_type, :tracking_id, :version, :voyage_number, :location, :completed_at])
    |> validate_required([:event_type, :completed_at])
    |> validate_inclusion(:event_type, HandlingEvent.event_type_values())
    |> validate_tracking_id_and_version()
    |> validate_location()
    |> validate_voyage_number()
  end

  def validate_tracking_id_and_version(changeset) do
    changeset
    |> validate_required([:tracking_id])
    |> check_tracking_id_and_version()
  end

  def check_tracking_id_and_version(changeset) do
    tracking_id = get_change(changeset, :tracking_id)

    try do
      cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
      put_change(changeset, :version, cargo.version)
    rescue
      _ ->
        add_error(changeset, :tracking_id, "is invalid")
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

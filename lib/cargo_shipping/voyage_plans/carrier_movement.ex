defmodule CargoShipping.VoyagePlans.CarrierMovement do
  @moduledoc """
  A VALUE OBJECT. A scheduled transit within a voyage.
  """
  import Ecto.Changeset

  require Logger

  alias CargoShipping.Utils

  @doc false
  def changeset(carrier_movement, attrs) do
    # Persist temp_id from form data
    temp_id = carrier_movement.temp_id || Utils.get(attrs, :temp_id)

    carrier_movement
    |> Map.put(:temp_id, temp_id)
    |> cast(attrs, [
      :previous_arrival_location,
      :departure_location,
      :arrival_location,
      :previous_arrival_time,
      :departure_time,
      :arrival_time,
      :delete
    ])
    |> validate_required([:departure_location, :arrival_location, :departure_time, :arrival_time])
    |> validate_departure_location()
    |> validate_departure_time()
    |> validate_arrival_location()
    |> validate_arrival_time()
    |> Utils.maybe_mark_for_deletion()
  end

  def validate_departure_location(changeset) do
    previous_arrival_location = get_field(changeset, :previous_arrival_location)
    departure_location = get_change(changeset, :departure_location)

    if is_nil(previous_arrival_location) || is_nil(departure_location) ||
         previous_arrival_location == departure_location do
      changeset
    else
      add_error(
        changeset,
        :departure_location,
        "should be the same as previous arrival location"
      )
    end
  end

  def validate_departure_time(changeset) do
    previous_arrival_time = get_field(changeset, :previous_arrival_time)
    departure_time = get_change(changeset, :departure_time)

    if is_nil(previous_arrival_time) || is_nil(departure_time) ||
         DateTime.compare(departure_time, previous_arrival_time) == :gt do
      changeset
    else
      add_error(changeset, :departure_time, "should be later than previous arrival time")
    end
  end

  def validate_arrival_location(changeset) do
    departure_location = get_change(changeset, :departure_location)
    arrival_location = get_change(changeset, :arrival_location)

    if is_nil(departure_location) || is_nil(arrival_location) ||
         departure_location != arrival_location do
      changeset
    else
      add_error(changeset, :arrival_location, "can't be the same as departure location")
    end
  end

  def validate_arrival_time(changeset) do
    departure_time = get_change(changeset, :departure_time)
    arrival_time = get_change(changeset, :arrival_time)

    if is_nil(departure_time) || is_nil(arrival_time) ||
         DateTime.compare(arrival_time, departure_time) == :gt do
      changeset
    else
      add_error(changeset, :arrival_time, "should be later than departure time")
    end
  end
end

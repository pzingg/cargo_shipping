defmodule CargoShipping.CargoBookings.Itinerary do
  @moduledoc """
  A VALUE OBJECT.

  An Itinerary consists of one or more Legs.
  """
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias CargoShipping.CargoBookings.Leg
  alias CargoShipping.VoyagePlans

  @end_of_days ~U[2050-12-31 23:59:59Z]

  @primary_key false
  embedded_schema do
    embeds_many :legs, Leg, on_replace: :delete
  end

  @doc false
  def changeset(itinerary, attrs) do
    itinerary
    |> cast(attrs, [])
    |> cast_embed(:legs, with: &Leg.changeset/2)
  end

  @doc """
  Test if the given handling event is expected when executing this itinerary.
  """
  def handling_event_expected(itinerary, handling_event) do
    case itinerary.legs do
      [] ->
        {:error, "invalid itinerary"}

      legs ->
        voyage_number = VoyagePlans.get_voyage_number_for_id!(handling_event.voyage_id)
        location = handling_event.location
        case handling_event.event_type do
          :RECEIVE ->
            # Check that the first leg's origin is the event's location
            first_leg = List.first(legs)
            expected = first_leg.load_location == location
            if expected do
              :ok
            else
              Logger.error(":RECEIVE #{location} does not match origin #{first_leg.load_location}")
              {:error, "receive origin mismatch"}
            end

          :LOAD ->
            # Check that the there is one leg with same load location and voyage
            expected = Enum.any?(legs, fn leg ->
              leg.load_location == location &&
                leg.voyage_id == handling_event.voyage_id
            end)
            if expected do
              :ok
            else
              Logger.error(":LOAD #{location} does not match any load location of voyage #{voyage_number}")
              {:error, "#{voyage_number} load mismatch"}
            end

          :UNLOAD ->
            # Check that the there is one leg with same unload location and voyage
            expected = Enum.any?(legs, fn leg ->
              leg.unload_location == location &&
                leg.voyage_id == handling_event.voyage_id
            end)
            if expected do
              :ok
            else
              Logger.error(":UNLOAD #{location} does not match any unload location of voyage #{voyage_number}")
              {:error, "#{voyage_number} unload mismatch"}
            end

          :CLAIM ->
            # Check that the last leg's destination is from the event's location
            last_leg = List.last(legs)
            expected = last_leg.unload_location == location
            if expected do
              :ok
            else
              Logger.error(":CLAIM #{location} does not match final leg's unload location")
              {:error, "claim destination mismatch"}
            end

          _ ->
            # :CUSTOMS
            :ok
        end
    end
  end

  def initial_departure_location(itinerary) do
    case itinerary.legs do
      [] ->
        "_"

      legs ->
        hd(legs).load_location
    end
  end

  def final_arrival_location(itinerary) do
    case itinerary.legs do
      [] ->
        "_"

      legs ->
        List.last(legs).unload_location
    end
  end

  def final_arrival_date(itinerary) do
    case itinerary.legs do
      [] ->
        @end_of_days

      legs ->
        List.last(legs).unload_time
    end
  end

  def satisfies?(nil, _route_specification), do: false

  def satisfies?(itinerary, route_specification) do
    initial_departure_location(itinerary) == route_specification.origin &&
      final_arrival_location(itinerary) == route_specification.destination &&
      final_arrival_date(itinerary) < route_specification.arrival_deadline
  end
end

defmodule CargoShipping.CargoBookings.Itinerary do
  @moduledoc """
  A VALUE OBJECT.

  An Itinerary consists of one or more Legs.
  """
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias CargoShipping.VoyageService
  alias CargoShipping.CargoBookings.Leg

  @end_of_days ~U[2049-12-31 23:59:59Z]

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

  def debug_itinerary(itinerary), do: debug_legs(itinerary.legs)

  def initial_leg(itinerary), do: List.first(itinerary.legs)

  def initial_departure_location(itinerary) do
    case initial_leg(itinerary) do
      nil ->
        "_"

      leg ->
        leg.load_location
    end
  end

  def final_leg(itinerary), do: List.last(itinerary.legs)

  def final_arrival_location(itinerary) do
    case final_leg(itinerary) do
      nil ->
        "_"

      leg ->
        leg.unload_location
    end
  end

  def final_arrival_date(itinerary) do
    case final_leg(itinerary) do
      nil ->
        @end_of_days

      leg ->
        leg.unload_time
    end
  end

  def find_leg(:LOAD, itinerary, location) do
    Enum.find(itinerary.legs, fn leg ->
      leg.load_location == location
    end)
  end

  def find_leg(:UNLOAD, itinerary, location) do
    Enum.find(itinerary.legs, fn leg ->
      leg.unload_location == location
    end)
  end

  @doc """
  Test that itinerary matches origin and destination requirements.
  """
  def satisfies?(nil, _route_specification), do: false

  def satisfies?(itinerary, route_specification) do
    initial_departure_location(itinerary) == route_specification.origin &&
      final_arrival_location(itinerary) == route_specification.destination &&
      final_arrival_date(itinerary) < route_specification.arrival_deadline
  end

  @doc """
  Test if the given handling event is expected when executing this itinerary.
  """
  def handling_event_expected(itinerary, handling_event) do
    case itinerary.legs do
      [] ->
        {:error, "invalid itinerary"}

      legs ->
        event_expected(
          handling_event.event_type,
          legs,
          handling_event.location,
          handling_event.voyage_id
        )
    end
  end

  defp event_expected(:CUSTOMS, _legs, _location, _voyage_id) do
    :ok
  end

  defp event_expected(event_type, legs, location, voyage_id) do
    case find_leg_for_event(event_type, legs, location, voyage_id) do
      {:ok, _found} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_leg_for_event(:RECEIVE, legs, location, _voyage_id) do
    # Check that the first leg's origin is the event's location
    first_leg = List.first(legs)

    if first_leg.load_location == location do
      {:ok, first_leg}
    else
      Logger.error(":RECEIVE at #{location} does not match origin #{first_leg.load_location}")

      debug_legs(legs)

      {:error, "receive origin mismatch"}
    end
  end

  defp find_leg_for_event(:LOAD, legs, location, voyage_id) do
    # Check that the there is one leg with same load location and voyage
    found =
      Enum.find(legs, fn leg ->
        leg.load_location == location &&
          leg.voyage_id == voyage_id
      end)

    if found do
      {:ok, found}
    else
      voyage_number = VoyageService.get_voyage_number_for_id!(voyage_id)

      if is_nil(voyage_id) do
        Logger.error(":LOAD at #{location} does not have a voyage id")
      else
        Logger.error(
          ":LOAD at #{location} does not match any load location of voyage #{voyage_number}"
        )
      end

      debug_legs(legs)

      {:error, "#{voyage_number} load mismatch"}
    end
  end

  defp find_leg_for_event(:UNLOAD, legs, location, voyage_id) do
    # Check that the there is one leg with same unload location and voyage
    found =
      Enum.any?(legs, fn leg ->
        leg.unload_location == location &&
          leg.voyage_id == voyage_id
      end)

    if found do
      {:ok, found}
    else
      voyage_number = VoyageService.get_voyage_number_for_id!(voyage_id)

      if is_nil(voyage_id) do
        Logger.error(":UNLOAD at #{location} does not have a voyage id")
      else
        Logger.error(
          ":UNLOAD at #{location} does not match any unload location of voyage #{voyage_number}"
        )
      end

      debug_legs(legs)

      {:error, "#{voyage_number} unload mismatch"}
    end
  end

  defp find_leg_for_event(:CLAIM, legs, location, _voyage_id) do
    # Check that the last leg's destination is from the event's location
    last_leg = List.last(legs)

    if last_leg.unload_location == location do
      {:ok, last_leg}
    else
      Logger.error(":CLAIM at #{location} does not match final unload location")
      debug_legs(legs)

      {:error, "claim destination mismatch"}
    end
  end

  defp debug_legs(legs) do
    for %{
          load_location: load_location,
          unload_location: unload_location,
          voyage_id: voyage_id
        } <- legs do
      voyage_number =
        VoyageService.get_voyage_number_for_id!(voyage_id)
        |> String.pad_trailing(6)

      Logger.error("  on voyage #{voyage_number} from #{load_location} to #{unload_location}")
    end
  end
end

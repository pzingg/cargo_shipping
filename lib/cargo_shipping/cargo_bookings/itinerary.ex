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

  @start_of_days ~U[2000-01-01 00:00:00Z]
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
    |> validate_contiguous_legs()
  end

  def validate_contiguous_legs(changeset) do
    {next_changeset, _} =
      get_field(changeset, :legs)
      |> Enum.reduce_while({changeset, nil}, fn leg, {cs, last_leg} ->
        if is_nil(last_leg) || last_leg.unload_location == leg.load_location do
          {:cont, {cs, leg}}
        else
          {:halt, {add_error(cs, :legs, "are not contiguous"), leg}}
        end
      end)

    next_changeset
  end

  @doc """
  Note: leg may NOT have status set (equivalent to :NOT_LOADED).
  """
  def ignore_leg?(%{status: :COMPLETED}), do: true
  def ignore_leg?(%{status: :SKIPPED}), do: true
  def ignore_leg?(_leg), do: false

  def initial_leg(itinerary), do: List.first(itinerary.legs)

  def initial_departure_location(itinerary) do
    case initial_leg(itinerary) do
      nil ->
        "_"

      leg ->
        leg.load_location
    end
  end

  def initial_departure_date(itinerary) do
    case initial_leg(itinerary) do
      nil ->
        @start_of_days

      leg ->
        leg.load_time
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
      initial_departure_date(itinerary) >= route_specification.earliest_departure &&
      final_arrival_date(itinerary) <= route_specification.arrival_deadline
  end

  @doc """
  Test if the given handling event is expected when executing this itinerary.
  """
  def matches_handling_event(itinerary, handling_event) do
    if Enum.empty?(itinerary.legs) do
      {:error, "invalid itinerary"}
    else
      find_leg_for_event(
        handling_event.event_type,
        itinerary,
        handling_event.location,
        handling_event.voyage_id
      )
    end
  end

  defp find_leg_for_event(event_type, itinerary, location, voyage_id)

  defp find_leg_for_event(:RECEIVE, %{legs: legs} = itinerary, location, _voyage_id) do
    # Check that the first leg's origin is the event's location
    first_leg = List.first(legs)

    if first_leg.load_location == location && first_leg.status == :NOT_LOADED do
      {:ok, itinerary, first_leg}
    else
      Logger.error(":RECEIVE at #{location} does not match origin #{first_leg.load_location}")
      debug_legs(legs)

      {:error, "receive origin mismatch"}
    end
  end

  defp find_leg_for_event(:LOAD, %{legs: legs} = itinerary, location, voyage_id) do
    # Check that the there is one leg with same load location and voyage
    {reversed_legs, found} =
      Enum.reduce(legs, {[], nil}, fn leg, {acc, f} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            ignore_leg?(leg) ->
              {leg, nil}

            leg.load_location != location ->
              {Map.put(leg, :status, :SKIPPED), nil}

            true ->
              matched_leg = Map.put(leg, :status, :ONBOARD_CARRIER)
              {matched_leg, matched_leg}
          end

        {[mapped_leg | acc], found_0}
      end)

    if found && found.voyage_id == voyage_id do
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}, found}
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

  defp find_leg_for_event(:UNLOAD, %{legs: legs} = itinerary, location, voyage_id) do
    # Check that the there is one leg with same unload location and voyage
    {reversed_legs, found} =
      Enum.reduce(legs, {[], nil}, fn leg, {acc, f} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            ignore_leg?(leg) ->
              {leg, nil}

            leg.unload_location != location ->
              {Map.put(leg, :status, :SKIPPED), nil}

            true ->
              matched_leg = Map.put(leg, :status, :COMPLETED)
              {matched_leg, matched_leg}
          end

        {[mapped_leg | acc], found_0}
      end)

    if found && found.voyage_id == voyage_id do
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}, found}
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

  defp find_leg_for_event(:CUSTOMS, %{legs: legs} = itinerary, location, _voyage_id) do
    # Check that the there is one leg with same unload location and voyage
    {reversed_legs, found} =
      Enum.reduce(legs, {[], nil}, fn leg, {acc, f} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            ignore_leg?(leg) ->
              {leg, nil}

            leg.unload_location != location ->
              {Map.put(leg, :status, :SKIPPED), nil}

            true ->
              matched_leg = Map.put(leg, :status, :COMPLETED)
              {matched_leg, matched_leg}
          end

        {[mapped_leg | acc], found_0}
      end)

    if found do
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}, found}
    else
      Logger.error(":CUSTOMS at #{location} does not match any unload location")
      debug_legs(legs)

      {:error, "customs destination mismatch"}
    end
  end

  defp find_leg_for_event(:CLAIM, %{legs: legs} = itinerary, location, _voyage_id) do
    # Check that the last leg's destination is from the event's location
    last_leg = List.last(legs)

    {reversed_legs, found, _last} =
      Enum.reduce(legs, {[], nil, last_leg}, fn leg, {acc, f, last} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            ignore_leg?(leg) ->
              {leg, nil}

            leg != last ->
              {Map.put(leg, :status, :SKIPPED), nil}

            true ->
              matched_leg = Map.put(leg, :status, :COMPLETED)
              {matched_leg, matched_leg}
          end

        {[mapped_leg | acc], found_0, last}
      end)

    if found do
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}, found}
    else
      Logger.error(":CLAIM at #{location} does not match final unload location")
      debug_legs(legs)

      {:error, "claim destination mismatch"}
    end
  end

  def debug_itinerary(itinerary) do
    Logger.error("itinerary")
    debug_legs(itinerary.legs)
  end

  defp debug_legs(legs) do
    for leg <- legs, do: debug_leg(leg)
  end

  # Note: leg may NOT have status set (equivalent to :NOT_LOADED).
  defp debug_leg(
         %{
           load_location: load_location,
           unload_location: unload_location,
           voyage_id: voyage_id
         } = leg
       ) do
    voyage_number =
      VoyageService.get_voyage_number_for_id!(voyage_id)
      |> String.pad_trailing(6)

    status = Map.get(leg, :status, :NOT_LOADED)

    Logger.error(
      "  on voyage #{voyage_number} from #{load_location} to #{unload_location} - #{status}"
    )
  end
end

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
  alias __MODULE__

  @start_of_days ~U[2000-01-01 00:00:00Z]
  @end_of_days ~U[2049-12-31 23:59:59Z]

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    embeds_many :legs, Leg, on_replace: :delete
  end

  def new(legs) do
    %Itinerary{}
    |> changeset(%{legs: coalesce_legs(legs)})
    |> apply_changes()
  end

  def legs_from_voyage(voyage) do
    Enum.map(voyage.schedule_items, fn item -> leg_from_voyage_item(voyage, item) end)
  end

  def leg_from_voyage_item(voyage, item) do
    %{
      voyage_id: voyage.id,
      load_location: item.departure_location,
      unload_location: item.arrival_location,
      load_time: item.departure_time,
      unload_time: item.arrival_time,
      status: :NOT_LOADED
    }
  end

  def single_leg_from_voyage(voyage) do
    origin = List.first(voyage.schedule_items)
    destination = List.last(voyage.schedule_items)

    %{
      voyage_id: voyage.id,
      load_location: origin.departure_location,
      unload_location: destination.arrival_location,
      load_time: origin.departure_time,
      unload_time: destination.arrival_time,
      status: :NOT_LOADED
    }
  end

  def coalesce_legs(legs) do
    {reversed_legs, _last} =
      Enum.reduce(legs, {[], nil}, fn leg, {acc, previous_leg} ->
        if is_nil(previous_leg) || leg.voyage_id != previous_leg.voyage_id do
          {[leg | acc], leg}
        else
          case List.pop_at(acc, 0) do
            {acc_leg, rest} when is_map(acc_leg) ->
              coalesced =
                acc_leg
                |> Map.put(:unload_location, leg.unload_location)
                |> Map.put(:unload_time, leg.unload_time)

              {[coalesced | rest], leg}

            _ ->
              {acc, leg}
          end
        end
      end)

    Enum.reverse(reversed_legs)
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
  def satisfies?(itinerary, route_specification, opts \\ [])

  def satisfies?(nil, _route_specification, _opts), do: false

  def satisfies?(itinerary, route_specification, opts) do
    must_satisfy_dates = Keyword.get(opts, :strict, false)

    cond do
      !(initial_departure_location(itinerary) == route_specification.origin &&
            final_arrival_location(itinerary) == route_specification.destination) ->
        false

      must_satisfy_dates &&
          !(initial_departure_date(itinerary) >= route_specification.earliest_departure &&
                final_arrival_date(itinerary) <= route_specification.arrival_deadline) ->
        false

      true ->
        true
    end
  end

  @doc """
  Test if the given handling event is expected when executing this itinerary.
  """
  def matches_handling_event(itinerary, handling_event) do
    cond do
      is_nil(itinerary) ->
        {:error, "no itinerary", nil}

      Enum.empty?(itinerary.legs) ->
        {:error, "empty itinerary", nil}

      true ->
        case find_match_for_event(
               itinerary,
               handling_event.event_type,
               handling_event.location,
               handling_event.voyage_id
             ) do
          {:ok, updated_itinerary} ->
            {:ok, updated_itinerary}

          {:error, message} ->
            {:error, message, nil}
        end
    end
  end

  defp find_match_for_event(itinerary, event_type, location, voyage_id)

  defp find_match_for_event(%{legs: legs} = itinerary, :RECEIVE, location, _voyage_id) do
    # Check that the first leg's origin is the event's location
    first_leg = List.first(legs)

    if first_leg.load_location == location && first_leg.status == :NOT_LOADED do
      {:ok, itinerary}
    else
      {:error, "RECEIVE at #{location} does not match origin #{first_leg.load_location}"}
    end
  end

  defp find_match_for_event(%{legs: legs} = itinerary, :LOAD, location, voyage_id) do
    # Check that the there is one leg with same load location and voyage
    {reversed_legs, found} =
      Enum.reduce(legs, {[], nil}, fn leg, {acc, f} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            Leg.completed?(leg) ->
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
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}}
    else
      voyage_number = VoyageService.get_voyage_number_for_id!(voyage_id)

      message =
        if is_nil(voyage_id) do
          "LOAD at #{location} does not have a voyage id"
        else
          "LOAD at #{location} does not match any load location of voyage #{voyage_number}"
        end

      {:error, message}
    end
  end

  defp find_match_for_event(%{legs: legs} = itinerary, :UNLOAD, location, voyage_id) do
    # Check that the there is one leg with same unload location and voyage
    {reversed_legs, found} =
      Enum.reduce(legs, {[], nil}, fn leg, {acc, f} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            Leg.completed?(leg) ->
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
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}}
    else
      voyage_number = VoyageService.get_voyage_number_for_id!(voyage_id)

      message =
        if is_nil(voyage_id) do
          "UNLOAD at #{location} does not have a voyage id"
        else
          "UNLOAD at #{location} does not match any unload location of voyage #{voyage_number}"
        end

      {:error, message}
    end
  end

  defp find_match_for_event(%{legs: legs} = itinerary, :CUSTOMS, location, _voyage_id) do
    # Check that the there is one leg with same unload location and voyage
    {reversed_legs, found} =
      Enum.reduce(legs, {[], nil}, fn leg, {acc, f} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            Leg.completed?(leg) ->
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
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}}
    else
      {:error, "CUSTOMS at #{location} does not match any unload location"}
    end
  end

  defp find_match_for_event(%{legs: legs} = itinerary, :CLAIM, location, _voyage_id) do
    # Check that the last leg's destination is from the event's location
    last_leg = List.last(legs)

    {reversed_legs, found, _last} =
      Enum.reduce(legs, {[], nil, last_leg}, fn leg, {acc, f, last} ->
        {mapped_leg, found_0} =
          cond do
            !is_nil(f) ->
              {leg, f}

            leg != last && Leg.completed?(leg) ->
              {leg, nil}

            leg != last ->
              {Map.put(leg, :status, :SKIPPED), nil}

            true ->
              matched_leg = Map.put(leg, :status, :CLAIMED)
              {matched_leg, matched_leg}
          end

        {[mapped_leg | acc], found_0, last}
      end)

    if found do
      {:ok, %{itinerary | legs: Enum.reverse(reversed_legs)}}
    else
      {:error, "CLAIM at #{location} does not match final unload location"}
    end
  end

  def split_completed_legs(%{legs: legs} = itinerary, origin \\ nil) do
    first_uncompleted = first_uncompleted_index(itinerary, origin)
    Enum.split(legs, first_uncompleted)
  end

  # Returns 1 + the highest leg index marked as :COMPLETED or :CLAIMED
  # Returns 0 if none completed
  def first_uncompleted_index(%{legs: legs} = _itinerary, origin) do
    last_completed_index =
      Enum.with_index(legs)
      |> Enum.reduce_while(-1, fn {leg, index}, acc ->
        if Leg.completed?(leg) do
          {:cont, index}
        else
          if origin && origin != leg.load_location do
            Logger.error(
              "load location #{leg.load_location} of first uncompleted leg #{index} does not match origin #{origin}"
            )
          end

          {:halt, acc}
        end
      end)

    last_completed_index + 1
  end

  def debug_itinerary(itinerary) do
    Logger.debug("itinerary")

    cond do
      is_nil(itinerary) -> Logger.debug("   no itinerary")
      Enum.empty?(itinerary.legs) -> Logger.debug("   empty itinerary")
      true -> debug_legs(itinerary.legs)
    end
  end

  defp debug_legs(legs) do
    for leg <- legs, do: debug_leg(leg)
  end

  # Note: leg may NOT have status set (equivalent to :NOT_LOADED).
  defp debug_leg(leg) do
    Logger.debug("  #{to_string(leg)}")
  end
end

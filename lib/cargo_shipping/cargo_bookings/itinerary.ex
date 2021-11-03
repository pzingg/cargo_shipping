defmodule CargoShipping.CargoBookings.Itinerary do
  @moduledoc """
  A VALUE OBJECT.

  An Itinerary consists of one or more Legs.
  """
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias CargoShipping.{VoyageService, Utils}
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
      |> Enum.with_index()
      |> Enum.reduce_while({changeset, nil}, fn {leg, index}, {cs, last_leg} ->
        load_location = leg.load_location

        if is_nil(last_leg) ||
             load_location == last_leg.unload_location ||
             (!is_nil(last_leg.actual_unload_location) &&
                load_location == last_leg.actual_unload_location) do
          {:cont, {cs, leg}}
        else
          {:halt, {add_error(cs, :legs, "#{index - 1} and #{index} are not contiguous"), leg}}
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
        Leg.actual_load_location(leg)
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

  def uncompleted_leg(%{legs: legs}) do
    Enum.drop_while(legs, &Leg.completed?(&1)) |> List.first()
  end

  def uncompleted_departure_location(itinerary) do
    case uncompleted_leg(itinerary) do
      nil ->
        "_"

      leg ->
        Leg.actual_load_location(leg)
    end
  end

  def uncompleted_departure_date(itinerary) do
    case uncompleted_leg(itinerary) do
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
        Leg.actual_unload_location(leg)
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
      Leg.actual_load_location(leg) == location
    end)
  end

  def find_leg(:UNLOAD, itinerary, location) do
    Enum.find(itinerary.legs, fn leg ->
      Leg.actual_unload_location(leg) == location
    end)
  end

  def legs_from_voyage(%{id: voyage_id, schedule_items: items} = _voyage) do
    legs_from_voyage_items(voyage_id, items)
  end

  def legs_from_voyage_items(voyage_id, items) do
    Enum.map(items, fn item -> leg_from_voyage_item(voyage_id, item) end)
  end

  def leg_from_voyage_item(voyage_id, item) do
    %{
      voyage_id: voyage_id,
      load_location: item.departure_location,
      unload_location: item.arrival_location,
      load_time: item.departure_time,
      unload_time: item.arrival_time,
      status: :NOT_LOADED
    }
  end

  def single_leg_from_voyage(%{id: voyage_id, schedule_items: items} = _voyage) do
    single_leg_from_voyage_items(voyage_id, items)
  end

  def single_leg_from_voyage_items(voyage_id, items) do
    origin = List.first(items)
    destination = List.last(items)

    %{
      voyage_id: voyage_id,
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

  @doc """
  Test that itinerary matches origin and destination requirements.
  """
  def satisfies?(itinerary, route_specification, opts \\ [])

  def satisfies?(nil, _route_specification, _opts), do: false

  def satisfies?(itinerary, route_specification, opts) do
    must_satisfy_dates = Keyword.get(opts, :strict, false)

    cond do
      !(uncompleted_departure_location(itinerary) == route_specification.origin &&
            final_arrival_location(itinerary) == route_specification.destination) ->
        false

      must_satisfy_dates &&
          !(uncompleted_departure_date(itinerary) >= route_specification.earliest_departure &&
                final_arrival_date(itinerary) <= route_specification.arrival_deadline) ->
        false

      true ->
        true
    end
  end

  def internal_itinerary_for_route_specification(itinerary, route_specification) do
    internal_itinerary_for(itinerary.legs, route_specification)
  end

  def internal_itinerary_for([], _route_specification), do: nil

  def internal_itinerary_for(legs, route_specification) do
    [first | rest] = legs

    single_itinerary_for(legs, route_specification) ||
      recursive_itinerary_for(first, 0, route_specification, rest)
  end

  def single_itinerary_for(legs, route_specification) do
    Enum.with_index(legs)
    |> Enum.reduce_while(nil, fn {leg, _index}, _acc ->
      case single_leg_for_voyage(leg.voyage_id, route_specification) do
        nil ->
          {:cont, nil}

        matched_leg ->
          # Done, the matched leg does it all.
          {:halt, Utils.from_struct([matched_leg]) |> Itinerary.new()}
      end
    end)
  end

  @doc """
  See if there is a voyage for a leg that can make an itinerary
  from the route specification's origin to the leg's destination.
  If so, the full itinerary can be built from that itinerary and
  the remaining legs.
  """
  def recursive_itinerary_for(leg, index, route_specification, remaining_legs) do
    partial_route_spec = %{
      route_specification
      | destination: leg.unload_location,
        arrival_deadline: leg.unload_time
    }

    case single_leg_for_voyage(leg.voyage_id, partial_route_spec) do
      nil ->
        if remaining_legs == [] do
          # Recursion exhausted
          nil
        else
          # Recurse
          [next | rest] = remaining_legs
          recursive_itinerary_for(next, index + 1, route_specification, rest)
        end

      matched_leg ->
        # Done, append remaining legs to the solution.
        Utils.from_struct([matched_leg | remaining_legs]) |> Itinerary.new()
    end
  end

  def itinerary_for_voyage(voyage_id, route_specification) do
    case single_leg_for_voyage(voyage_id, route_specification) do
      nil -> nil
      leg -> List.wrap(leg) |> Itinerary.new()
    end
  end

  def single_leg_for_voyage(voyage_id, route_specification) do
    case VoyageService.find_items_for_route_specification(voyage_id, route_specification) do
      {:ok, items} -> single_leg_from_voyage_items(voyage_id, items)
      _ -> nil
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
            updated_itinerary =
              update_for_unexpected_event(
                itinerary,
                handling_event.event_type,
                handling_event.location,
                handling_event.voyage_id,
                handling_event.completed_at
              )

            {:error, message, updated_itinerary}
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

  defp update_for_unexpected_event(
         %{legs: legs} = itinerary,
         :RECEIVE,
         location,
         _voyage_id,
         completed_at
       ) do
    %{
      itinerary
      | legs:
          List.update_at(legs, current_index(itinerary), fn leg ->
            %{leg | actual_load_location: location, load_time: completed_at}
          end)
    }
  end

  defp update_for_unexpected_event(
         %{legs: legs} = itinerary,
         :LOAD,
         location,
         _voyage_id,
         completed_at
       ) do
    %{
      itinerary
      | legs:
          List.update_at(legs, current_index(itinerary), fn leg ->
            %{
              leg
              | status: :ONBOARD_CARRIER,
                actual_load_location: location,
                load_time: completed_at
            }
          end)
    }
  end

  defp update_for_unexpected_event(
         %{legs: legs} = itinerary,
         :UNLOAD,
         location,
         _voyage_id,
         completed_at
       ) do
    %{
      itinerary
      | legs:
          List.update_at(legs, current_index(itinerary), fn leg ->
            %{
              leg
              | status: :COMPLETED,
                actual_unload_location: location,
                unload_time: completed_at
            }
          end)
    }
  end

  defp update_for_unexpected_event(
         %{legs: legs} = itinerary,
         :CUSTOMS,
         location,
         _voyage_id,
         completed_at
       ) do
    %{
      itinerary
      | legs:
          List.update_at(legs, current_index(itinerary), fn leg ->
            %{
              leg
              | status: :COMPLETED,
                actual_unload_location: location,
                unload_time: completed_at
            }
          end)
    }
  end

  defp update_for_unexpected_event(
         %{legs: legs} = itinerary,
         :CLAIM,
         location,
         _voyage_id,
         completed_at
       ) do
    %{
      itinerary
      | legs:
          List.update_at(legs, current_index(itinerary), fn leg ->
            %{leg | status: :CLAIMED, actual_unload_location: location, unload_time: completed_at}
          end)
    }
  end

  def split_completed_legs(%{legs: legs} = itinerary, origin \\ nil) do
    first_uncompleted_index = last_completed_index(itinerary, origin) + 1
    Enum.split(legs, first_uncompleted_index)
  end

  def current_leg(%{legs: legs} = itinerary) do
    Enum.at(legs, current_index(itinerary, nil))
  end

  def last_completed_leg(%{legs: legs} = itinerary) do
    Enum.at(legs, last_completed_index(itinerary, nil))
  end

  def current_index(itinerary, origin \\ nil) do
    last_completed_index(itinerary, origin) + 1
  end

  # Returns the highest leg index marked as :COMPLETED or :CLAIMED
  # Returns -1 if none completed
  def last_completed_index(%{legs: legs} = _itinerary, origin \\ nil) do
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

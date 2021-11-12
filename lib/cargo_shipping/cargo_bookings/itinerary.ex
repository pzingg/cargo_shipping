defmodule CargoShipping.CargoBookings.Itinerary do
  @moduledoc """
  A VALUE OBJECT.

  An Itinerary consists of one or more Legs.
  """
  import Ecto.Changeset

  require Logger

  alias CargoShipping.{VoyageService, Utils}
  alias CargoShipping.CargoBookings.Leg
  alias CargoShippingSchemas.{Itinerary, RouteSpecification}

  @start_of_days ~U[2000-01-01 00:00:00Z]
  @end_of_days ~U[2049-12-31 23:59:59Z]

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

  def first_uncompleted_leg(%{legs: legs}) do
    Enum.drop_while(legs, &Leg.completed?(&1)) |> List.first()
  end

  def last_completed_leg(%{legs: legs} = _itinerary) do
    Enum.reduce_while(legs, nil, fn leg, acc ->
      if Leg.completed?(leg) do
        {:cont, leg}
      else
        {:halt, acc}
      end
    end)
  end

  @doc """
  Returns the first leg index not marked as :COMPLETED or :CLAIMED
  Returns 0 if no legs are completed.
  """
  def first_uncompleted_index(%{legs: legs} = _itinerary) do
    first_uncompleted =
      Enum.with_index(legs)
      |> Enum.drop_while(fn {leg, _index} -> Leg.completed?(leg) end)
      |> Enum.take(1)

    case first_uncompleted do
      [] -> 0
      [{_leg, index} | _] -> index
    end
  end

  def last_completed_index(itinerary), do: first_uncompleted_index(itinerary) - 1

  @doc """
  Can be called for a cargo that has no itinerary defined yet.
  """
  def split_completed_legs(nil), do: {[], []}

  def split_completed_legs(%{legs: legs} = itinerary) do
    Enum.split(legs, first_uncompleted_index(itinerary))
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

  def to_route_specification(itinerary, original_route_spec \\ nil) do
    route_specification = %RouteSpecification{
      origin: initial_departure_location(itinerary),
      destination: final_arrival_location(itinerary),
      earliest_departure: initial_departure_date(itinerary),
      arrival_deadline: final_arrival_date(itinerary)
    }

    if is_nil(original_route_spec) do
      route_specification
    else
      %RouteSpecification{
        route_specification
        | earliest_departure: original_route_spec.earliest_departure,
          arrival_deadline: original_route_spec.arrival_deadline
      }
    end
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
          {:halt, Utils.from_struct([matched_leg]) |> new()}
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
        Utils.from_struct([matched_leg | remaining_legs]) |> new()
    end
  end

  def itinerary_for_voyage(voyage_id, route_specification) do
    case single_leg_for_voyage(voyage_id, route_specification) do
      nil -> nil
      leg -> List.wrap(leg) |> new()
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
  def matches_handling_event(itinerary, handling_event, opts \\ []) do
    cond do
      is_nil(itinerary) ->
        {:error, "no itinerary", nil}

      Enum.empty?(itinerary.legs) ->
        {:error, "empty itinerary", nil}

      true ->
        {scope, voyage_id, leg_location, next_status} =
          case handling_event.event_type do
            :RECEIVE ->
              {:first, nil, :LOAD, :NOT_LOADED}

            :LOAD ->
              {:first_uncompleted, handling_event.voyage_id, :LOAD, :ONBOARD_CARRIER}

            :UNLOAD ->
              {:first_uncompleted, handling_event.voyage_id, :UNLOAD, :COMPLETED}

            :CUSTOMS ->
              {:last, nil, :UNLOAD, :IN_CUSTOMS}

            :CLAIM ->
              {:last, nil, :UNLOAD, :CLAIMED}
          end

        ignore_completion = Keyword.get(opts, :ignore_completion, false)

        real_scope =
          if scope == :first_uncompleted && ignore_completion do
            :any
          else
            scope
          end

        {before, leg, rest, voyage_matched?, location_matched?} =
          if real_scope == :any do
            count = Enum.count(itinerary.legs)

            {voyage_match, location_match} =
              Enum.reduce_while(0..(count - 1), {-1, -1}, fn i, {vm_i, lc_i} ->
                leg = Enum.at(itinerary.legs, i)

                case test_event(leg_location, leg, voyage_id, handling_event.location) do
                  {true, true} ->
                    {:halt, {i, i}}

                  {true, false} ->
                    {:cont, {i, lc_i}}

                  _ ->
                    {:cont, {vm_i, lc_i}}
                end
              end)

            if location_match >= 0 do
              {b, l, r} = split_at(itinerary, location_match)
              {b, l, r, true, true}
            else
              {b, l, r} = split_at(itinerary, voyage_match)
              {b, l, r, voyage_match >= 0, false}
            end
          else
            {b, l, r} = split_for_scope(itinerary, scope)

            {voyage_match, location_match} =
              test_event(leg_location, l, voyage_id, handling_event.location)

            {b, l, r, voyage_match, location_match}
          end

        voyage_number =
          case VoyageService.get_voyage_number_for_id(voyage_id) do
            nil -> ""
            number -> " on voyage #{number}"
          end

        error_message =
          "no match for #{handling_event.event_type} at #{handling_event.location}#{voyage_number} (scope: #{scope})"

        itinerary_to_return =
          if voyage_matched? && Keyword.get(opts, :update_itinerary, false) do
            updated_leg = update_leg(leg, leg_location, next_status, handling_event)

            updated_itinerary = build_update(before, updated_leg, rest)
            debug_itinerary(updated_itinerary, "updated_itinerary")
            updated_itinerary
          else
            itinerary
          end

        if location_matched? do
          {:ok, itinerary_to_return}
        else
          {:error, error_message, itinerary_to_return}
        end
    end
  end

  defp test_event(leg_location, leg, voyage_id, handling_event_location) do
    case leg_location do
      :LOAD ->
        cond do
          is_nil(leg) || (!is_nil(voyage_id) && voyage_id != leg.voyage_id) ->
            {false, false}

          handling_event_location != leg.load_location &&
              handling_event_location != leg.actual_load_location ->
            {true, false}

          true ->
            {true, true}
        end

      :UNLOAD ->
        cond do
          is_nil(leg) || (!is_nil(voyage_id) && voyage_id != leg.voyage_id) ->
            {false, false}

          handling_event_location != leg.unload_location &&
              handling_event_location != leg.actual_unload_location ->
            {true, false}

          true ->
            {true, true}
        end
    end
  end

  defp update_leg(leg, :LOAD, status, event) do
    if leg.load_location == event.location do
      %{leg | status: status, load_time: event.completed_at}
    else
      %{
        leg
        | actual_load_location: event.location,
          status: status,
          load_time: event.completed_at
      }
    end
  end

  defp update_leg(leg, :UNLOAD, status, event) do
    if leg.unload_location == event.location do
      %{leg | status: status, unload_time: event.completed_at}
    else
      %{
        leg
        | actual_unload_location: event.location,
          status: status,
          unload_time: event.completed_at
      }
    end
  end

  defp build_update(before, leg, rest) do
    %{legs: before ++ [leg] ++ rest}
  end

  defp do_split([]), do: {nil, []}

  defp do_split([a | rest]), do: {a, rest}

  def split_at(%{legs: legs}, position) do
    {before, current} = Enum.split(legs, max(0, position))
    {leg, rest} = do_split(current)
    {before, leg, rest}
  end

  def split_for_scope(%{legs: []}, _scope), do: {[], nil, []}

  def split_for_scope(%{legs: [leg | rest]}, :first) do
    {[], leg, rest}
  end

  def split_for_scope(%{legs: legs}, :last) do
    count = Enum.count(legs)

    if count < 2 do
      {leg, rest} = do_split(legs)
      {[], leg, rest}
    else
      {before, [leg | rest]} = Enum.split(legs, count - 1)
      {before, leg, rest}
    end
  end

  def split_for_scope(%{legs: legs} = itinerary, :first_uncompleted) do
    index = first_uncompleted_index(itinerary)

    {before, [leg | rest]} = Enum.split(legs, index)
    {before, leg, rest}
  end

  def debug_itinerary(itinerary, title \\ "itinerary") do
    Logger.debug(title)

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
    Logger.debug("  #{Leg.string_from(leg)}")
  end
end

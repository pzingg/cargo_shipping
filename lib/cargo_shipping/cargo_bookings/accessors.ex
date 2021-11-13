defmodule CargoShipping.CargoBookings.Accessors do
  @moduledoc """
  Read-only accessors to objects in CargoBookings context.
  """
  alias CargoShipping.VoyageService

  # RouteSpecification accessors

  defdelegate debug_route_specification(route_specification, title),
    to: CargoShipping.CargoBookings.RouteSpecification

  def cargo_origin(cargo) do
    cargo.route_specification.origin
  end

  def cargo_destination(cargo) do
    cargo.route_specification.destination
  end

  def cargo_arrival_deadline(cargo) do
    cargo.route_specification.arrival_deadline
  end

  # Delivery accessors

  defdelegate debug_delivery(delivery), to: CargoShipping.CargoBookings.Delivery

  def cargo_misdirected?(%{delivery: nil}), do: false
  def cargo_misdirected?(%{delivery: delivery}), do: delivery.misdirected?

  def cargo_routed?(cargo), do: cargo_routing_status(cargo) != :NOT_ROUTED

  def cargo_misrouted?(cargo), do: cargo_routing_status(cargo) == :MISROUTED

  def cargo_routing_status(%{delivery: nil}), do: :NOT_ROUTED
  def cargo_routing_status(%{delivery: delivery}), do: delivery.routing_status

  def cargo_transport_status(%{delivery: nil}), do: :UNKNOWN
  def cargo_transport_status(%{delivery: delivery}), do: delivery.transport_status

  def cargo_last_event_type(%{delivery: nil}), do: nil
  def cargo_last_event_type(%{delivery: delivery}), do: delivery.last_event_type

  def cargo_last_known_location(%{delivery: nil}), do: nil
  def cargo_last_known_location(%{delivery: delivery}), do: delivery.last_known_location

  def cargo_next_expected_activity(%{delivery: nil}), do: nil

  def cargo_next_expected_activity(%{delivery: delivery} = _cargo),
    do: delivery.next_expected_activity

  def cargo_current_voyage_number(%{delivery: nil}), do: nil

  def cargo_current_voyage_number(%{delivery: delivery}) do
    VoyageService.get_voyage_number_for_id(delivery.current_voyage_id)
  end

  # Itinerary accessors

  @start_of_days ~U[2000-01-01 00:00:00Z]
  @end_of_days ~U[2049-12-31 23:59:59Z]

  defdelegate debug_itinerary(itinerary, title), to: CargoShipping.CargoBookings.Itinerary

  def itinerary_completed_legs(%{itinerary: nil}), do: []

  def itinerary_completed_legs(%{itinerary: itinerary}) do
    {completed, _uncompleted} = itinerary_split_completed_legs(itinerary)
    completed
  end

  @doc """
  Can be called for a cargo that has no itinerary defined yet.
  """
  def itinerary_split_completed_legs(nil), do: {[], []}

  def itinerary_split_completed_legs(%{legs: legs} = itinerary) do
    Enum.split(legs, itinerary_first_uncompleted_index(itinerary))
  end

  def itinerary_initial_leg(nil), do: []
  def itinerary_initial_leg(itinerary), do: List.first(itinerary.legs)

  def itinerary_initial_departure_location(itinerary) do
    case itinerary_initial_leg(itinerary) do
      nil ->
        "_"

      leg ->
        leg_actual_load_location(leg)
    end
  end

  def itinerary_initial_departure_date(itinerary) do
    case itinerary_initial_leg(itinerary) do
      nil ->
        @start_of_days

      leg ->
        leg.load_time
    end
  end

  def itinerary_final_leg(itinerary), do: List.last(itinerary.legs)

  def itinerary_final_arrival_location(itinerary) do
    case itinerary_final_leg(itinerary) do
      nil ->
        "_"

      leg ->
        leg_actual_unload_location(leg)
    end
  end

  def itinerary_final_arrival_date(itinerary) do
    case itinerary_final_leg(itinerary) do
      nil ->
        @end_of_days

      leg ->
        leg.unload_time
    end
  end

  def itinerary_first_uncompleted_leg(%{legs: legs}) do
    Enum.drop_while(legs, &leg_completed?(&1)) |> List.first()
  end

  def itinerary_last_completed_leg(%{legs: legs} = _itinerary) do
    Enum.reduce_while(legs, nil, fn leg, acc ->
      if leg_completed?(leg) do
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
  def itinerary_first_uncompleted_index(%{legs: legs} = _itinerary) do
    first_uncompleted =
      Enum.with_index(legs)
      |> Enum.drop_while(fn {leg, _index} -> leg_completed?(leg) end)
      |> Enum.take(1)

    case first_uncompleted do
      [] -> 0
      [{_leg, index} | _] -> index
    end
  end

  def itinerary_last_completed_index(itinerary) do
    itinerary_first_uncompleted_index(itinerary) - 1
  end

  @doc """
  Test that itinerary matches origin and destination requirements.
  """
  def itinerary_satisfies?(itinerary, route_specification, opts \\ [])

  def itinerary_satisfies?(nil, _route_specification, _opts), do: false

  def itinerary_satisfies?(itinerary, route_specification, opts) do
    must_satisfy_dates = Keyword.get(opts, :strict, false)

    cond do
      !(itinerary_initial_departure_location(itinerary) == route_specification.origin &&
            itinerary_final_arrival_location(itinerary) ==
              route_specification.destination) ->
        false

      must_satisfy_dates &&
          !(itinerary_initial_departure_date(itinerary) >=
              route_specification.earliest_departure &&
                itinerary_final_arrival_date(itinerary) <=
                  route_specification.arrival_deadline) ->
        false

      true ->
        true
    end
  end

  # Leg accessors

  @leg_completed_values [:SKIPPED, :COMPLETED, :IN_CUSTOMS, :CLAIMED]

  defdelegate debug_leg(leg), to: CargoShipping.CargoBookings.Leg

  def leg_completed?(nil), do: false

  def leg_completed?(leg) do
    Enum.member?(@leg_completed_values, Map.get(leg, :status, :NOT_LOADED))
  end

  def leg_actual_load_location(nil), do: nil

  def leg_actual_load_location(leg) do
    Map.get(leg, :actual_load_location) || leg.load_location
  end

  def leg_actual_unload_location(nil), do: nil

  def leg_actual_unload_location(leg) do
    Map.get(leg, :actual_unload_location) || leg.unload_location
  end

  # HandlingEvent accessors

  defdelegate debug_handling_event(handling_event), to: CargoShipping.CargoBookings.HandlingEvent
end

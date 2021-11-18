defmodule CargoShipping.CargoLifecycleScenarioTest do
  use CargoShipping.DataCase

  require Logger

  alias CargoShipping.{CargoBookings, CargoBookingService, HandlingEventService, VoyageService}
  alias CargoShipping.CargoBookings.{Accessors, Itinerary}

  @tag hibernate_data: :all
  test "cargo undergoes lifecycle changes" do
    # Test setup: A cargo should be shipped from Hongkong to Stockholm,
    # and it should arrive in no more than two weeks.
    origin = "CNHKG"
    destination = "SESTO"
    earliest_departure = ~U[2009-02-01 00:00:00Z]
    arrival_deadline = ~U[2009-03-18 00:00:00Z]

    ## Use case 1: booking

    # A new cargo is booked, and the unique tracking id is assigned to the cargo.
    tracking_id = CargoBookingService.book_new_cargo(origin, destination, arrival_deadline)

    # The tracking id can be used to lookup the cargo in the repository.

    # Important: The cargo, and thus the domain model, is responsible for determining
    # the status of the cargo, whether it is on the right track or not and so on.
    # This is core domain logic.

    # Tracking the cargo basically amounts to presenting information extracted from
    # the cargo aggregate in a suitable way.

    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo
    assert cargo.delivery.transport_status == :NOT_RECEIVED
    assert cargo.delivery.routing_status == :NOT_ROUTED
    refute cargo.delivery.last_event_id
    refute cargo.delivery.misdirected?
    refute cargo.delivery.eta
    refute cargo.delivery.next_expected_activity

    ## Use case 2: routing

    # A number of possible routes for this cargo is requested and may be
    # presented to the customer in some way for him/her to choose from.
    # Selection could be affected by things like price and time of delivery,
    # but this test simply uses an arbitrary selection to mimic that process.

    # The cargo is then assigned to the selected route, described by an itinerary.

    {remaining_route_spec, itineraries} =
      CargoBookingService.request_possible_routes_for_cargo(cargo)

    assert remaining_route_spec
    assert remaining_route_spec == cargo.route_specification

    assert itineraries
    itinerary = select_prefered_itinerary(itineraries)
    refute itinerary.patch_uncompleted_leg?

    {:ok, _cargo} = CargoBookingService.assign_cargo_to_route(cargo, itinerary)

    Logger.warn("Line 62, after routing")

    # Wait for event bus
    Process.sleep(500)
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    Accessors.debug_route_specification(cargo.route_specification, "route")
    Accessors.debug_itinerary(cargo.itinerary, "itinerary")
    Accessors.debug_delivery(cargo.delivery)

    assert cargo.delivery.transport_status == :NOT_RECEIVED
    assert cargo.delivery.routing_status == :ROUTED
    refute cargo.delivery.last_event_id
    assert cargo.delivery.eta
    assert cargo.delivery.next_expected_activity
    assert cargo.delivery.next_expected_activity.event_type == :RECEIVE
    assert cargo.delivery.next_expected_activity.location == "CNHKG"

    ## Use case 3: handling

    # A handling event registration attempt will be formed from parsing
    # the data coming in as a handling report either via
    # the web service interface or as an uploaded CSV file.

    # The handling event factory tries to create a HandlingEvent from the attempt,
    # and if the factory decides that this is a plausible handling event, it is stored.
    # If the attempt is invalid, for example if no cargo exists for the specfied tracking id,
    # the attempt is rejected.

    # Handling begins: cargo is received in Hongkong.

    handling_params = %{
      completed_at: ~U[2009-03-01 00:00:00Z],
      tracking_id: tracking_id,
      location: "CNHKG",
      event_type: :RECEIVE
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.transport_status == :IN_PORT
    assert cargo.delivery.last_known_location == "CNHKG"
    assert cargo.delivery.last_event_id

    ## Next event: Load onto voyage in Hong Kong

    current_leg = Itinerary.find_leg(:LOAD, cargo.itinerary, "CNHKG")
    voyage_number = VoyageService.get_voyage_number_for_id(current_leg.voyage_id)
    assert voyage_number

    handling_params = %{
      completed_at: ~U[2009-03-03 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: voyage_number,
      location: "CNHKG",
      event_type: :LOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.transport_status == :ONBOARD_CARRIER
    assert cargo.delivery.current_voyage_id == current_leg.voyage_id
    assert cargo.delivery.last_known_location == "CNHKG"
    assert cargo.delivery.last_event_id
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity
    assert cargo.delivery.next_expected_activity.event_type == :UNLOAD
    assert cargo.delivery.next_expected_activity.voyage_id == current_leg.voyage_id
    assert cargo.delivery.next_expected_activity.location == current_leg.unload_location

    # Here's an attempt to register a handling event that's not valid
    # because there is no voyage with the specified voyage number,
    # and there's no location with the specified UN Locode either.

    # This attempt will be rejected and will not affect the cargo delivery in any way.
    handling_params = %{
      completed_at: ~U[2009-03-05 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "XX000",
      location: "ZZZZZ",
      event_type: :LOAD
    }

    Logger.warn("Line 150: bad handling params will fail!")

    {:error, changeset} = HandlingEventService.register_handling_event(handling_params)
    assert changeset.errors[:voyage_number] == {"is invalid", []}
    assert changeset.errors[:location] == {"is invalid", []}

    ## (Incorrectly) unload cargo in Shanghai.

    handling_params = %{
      completed_at: ~U[2009-03-07 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: voyage_number,
      location: "CNSHA",
      event_type: :UNLOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)

    # Check current state - cargo is misdirected!
    assert cargo.delivery.transport_status == :IN_PORT
    refute cargo.delivery.current_voyage_id
    assert cargo.delivery.last_known_location == "CNSHA"
    assert cargo.delivery.last_event_id
    assert cargo.delivery.misdirected?
    refute cargo.delivery.next_expected_activity

    ## Cargo needs to be rerouted

    # Specify a new route, this time from Shanghai (where it was
    # incorrectly unloaded) to Stockholm.

    from_shanghai = %{
      origin: "CNSHA",
      destination: "SESTO",
      earliest_departure: earliest_departure,
      arrival_deadline: arrival_deadline
    }

    Logger.warn("Line 192, rerouting")

    {:ok, _cargo} = CargoBookingService.change_destination(cargo, from_shanghai)

    # Wait for EventBus
    Process.sleep(500)
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.routing_status == :MISROUTED
    assert cargo.delivery.last_event_id
    refute cargo.delivery.next_expected_activity

    # Repeat procedure of selecting one out of a number of possible
    # routes satisfying the route spec.

    {remaining_route_spec, itineraries} =
      CargoBookingService.request_possible_routes_for_cargo(cargo)

    assert remaining_route_spec
    assert remaining_route_spec.origin == "CNSHA"

    completed_legs = Accessors.itinerary_completed_legs(cargo)

    assert Enum.count(completed_legs) == 1
    leg = List.first(completed_legs)
    assert leg.unload_location == "USNYC"
    assert leg.actual_unload_location == "CNSHA"

    assert itineraries
    itinerary = select_prefered_itinerary(itineraries)

    Logger.warn("Line 222, prefered itinerary")

    Accessors.debug_itinerary(itinerary, "itinerary")

    assert Enum.count(itinerary.legs) == 3
    leg = List.first(itinerary.legs)
    assert leg.load_location == "CNSHA"
    assert leg.unload_location == "CNHKG"

    refute itinerary.patch_uncompleted_leg?

    {:ok, _cargo} = CargoBookingService.assign_cargo_to_route(cargo, itinerary)

    # Wait for EventBus
    Process.sleep(500)
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)

    Logger.warn("Line 239, after re-routing")

    Accessors.debug_route_specification(cargo.route_specification, "route")
    Accessors.debug_itinerary(cargo.itinerary, "itinerary")
    Accessors.debug_delivery(cargo.delivery)

    # New itinerary should satisfy new route
    assert cargo.delivery.routing_status == :ROUTED
    assert cargo.delivery.transport_status != :NOT_RECEIVED
    assert cargo.delivery.last_event_id

    ## Cargo has been rerouted, shipping continues

    # Load in Shanghai

    handling_params = %{
      completed_at: ~U[2009-03-09 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "0400S",
      location: "CNSHA",
      event_type: :LOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    v400s = VoyageService.get_voyage_id_for_number("0400S")
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.current_voyage_id == v400s
    assert cargo.delivery.last_known_location == "CNSHA"
    assert cargo.delivery.transport_status == :ONBOARD_CARRIER
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :UNLOAD
    assert cargo.delivery.next_expected_activity.location == "CNHKG"
    assert cargo.delivery.next_expected_activity.voyage_id == v400s

    # Unload in Hong Kong

    handling_params = %{
      completed_at: ~U[2009-03-11 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "0400S",
      location: "CNHKG",
      event_type: :UNLOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    v100 = VoyageService.get_voyage_id_for_number("V100")
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    refute cargo.delivery.current_voyage_id
    assert cargo.delivery.last_known_location == "CNHKG"
    assert cargo.delivery.transport_status == :IN_PORT
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :LOAD
    assert cargo.delivery.next_expected_activity.location == "CNHKG"
    assert cargo.delivery.next_expected_activity.voyage_id == v100

    # Load in Hong Kong

    handling_params = %{
      completed_at: ~U[2009-03-13 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V100",
      location: "CNHKG",
      event_type: :LOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.current_voyage_id == v100
    assert cargo.delivery.last_known_location == "CNHKG"
    assert cargo.delivery.transport_status == :ONBOARD_CARRIER
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :UNLOAD
    assert cargo.delivery.next_expected_activity.location == "USNYC"
    assert cargo.delivery.next_expected_activity.voyage_id == v100

    # Unload in New York

    handling_params = %{
      completed_at: ~U[2009-03-19 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V100",
      location: "USNYC",
      event_type: :UNLOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    refute cargo.delivery.current_voyage_id
    assert cargo.delivery.last_known_location == "USNYC"
    assert cargo.delivery.transport_status == :IN_PORT
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :LOAD
    assert cargo.delivery.next_expected_activity.location == "USNYC"

    # Load in New York

    handling_params = %{
      completed_at: ~U[2009-03-21 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V200",
      location: "USNYC",
      event_type: :LOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    v200 = VoyageService.get_voyage_id_for_number("V200")
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.current_voyage_id == v200
    assert cargo.delivery.last_known_location == "USNYC"
    assert cargo.delivery.transport_status == :ONBOARD_CARRIER
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :UNLOAD
    assert cargo.delivery.next_expected_activity.location == "SESTO"
    assert cargo.delivery.next_expected_activity.voyage_id == v200

    # Unload in Stockholm

    handling_params = %{
      completed_at: ~U[2009-03-27 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V200",
      location: "SESTO",
      event_type: :UNLOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    refute cargo.delivery.current_voyage_id
    assert cargo.delivery.last_known_location == "SESTO"
    assert cargo.delivery.transport_status == :IN_PORT
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :CLAIM
    assert cargo.delivery.next_expected_activity.location == "SESTO"

    # Finally, cargo is claimed in Stockholm. This ends the cargo lifecycle
    # from our perspective.

    handling_params = %{
      completed_at: ~U[2009-03-29 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: nil,
      location: "SESTO",
      event_type: :CLAIM
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # TODO: Verify that :cargo_arrived event was received

    # Check current state - should be ok
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    refute cargo.delivery.current_voyage_id
    assert cargo.delivery.last_known_location == "SESTO"
    assert cargo.delivery.transport_status == :CLAIMED
    refute cargo.delivery.misdirected?
    refute cargo.delivery.next_expected_activity
  end

  ## Utility stubs

  defp select_prefered_itinerary(itineraries) when is_list(itineraries) do
    case List.first(itineraries) do
      nil -> nil
      %{itinerary: itinerary, cost: _cost} -> itinerary
    end
  end

  defp select_prefered_itinerary(_), do: nil
end

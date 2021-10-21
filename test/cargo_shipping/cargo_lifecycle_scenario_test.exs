defmodule CargoShipping.CargoLifecycleScenarioTest do
  use CargoShipping.DataCase

  require Logger

  alias CargoShipping.{CargoBookings, CargoBookingService, HandlingEventService, VoyageService}

  test "cargo undergoes lifecycle changes" do
    # Test setup: A cargo should be shipped from Hongkong to Stockholm,
    # and it should arrive in no more than two weeks.
    origin = "CNHKG"
    destination = "SESTO"
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
    refute cargo.delivery.misdirected?
    assert is_nil(cargo.delivery.eta)
    assert is_nil(cargo.delivery.next_expected_activity)

    ## Use case 2: routing

    # A number of possible routes for this cargo is requested and may be
    # presented to the customer in some way for him/her to choose from.
    # Selection could be affected by things like price and time of delivery,
    # but this test simply uses an arbitrary selection to mimic that process.

    # The cargo is then assigned to the selected route, described by an itinerary. */
    itineraries = CargoBookingService.possible_routes_for_cargo(cargo)
    refute Enum.empty?(itineraries)
    itinerary = select_prefered_itinerary(itineraries)
    attrs = CargoBookings.assign_cargo_to_route(cargo, itinerary)
    {:ok, cargo} = CargoBookings.update_cargo(cargo, attrs)

    assert cargo.delivery.transport_status == :NOT_RECEIVED
    assert cargo.delivery.routing_status == :ROUTED
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
    attrs = %{
      completed_at: ~U[2009-03-01 00:00:00Z],
      tracking_id: tracking_id,
      location: "CNHKG",
      event_type: :RECEIVE
    }

    {:ok, _event} = HandlingEventService.register_handling_event(attrs)

    # TODO wait for event
    Process.sleep(500)

    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo
    assert cargo.delivery.transport_status == :IN_PORT
    assert cargo.delivery.last_known_location == "CNHKG"

    # Next event: Load onto voyage CM003 in Hongkong
    v100 = VoyageService.get_voyage_id_for_number!("V100")
    assert v100

    attrs = %{
      completed_at: ~U[2009-03-03 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V100",
      location: "CNHKG",
      event_type: :LOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(attrs)

    # TODO wait for event
    Process.sleep(500)

    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo
    assert cargo.delivery.transport_status == :ONBOARD_CARRIER
    assert cargo.delivery.current_voyage_id == v100
    assert cargo.delivery.last_known_location == "CNHKG"
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity
    assert cargo.delivery.next_expected_activity.event_type == :UNLOAD
    assert cargo.delivery.next_expected_activity.voyage_id == :UNLOAD
    assert cargo.delivery.next_expected_activity.location == "USNYC"
  end

  ## Utility stubs

  def select_prefered_itinerary(itineraries), do: List.first(itineraries)
end

defmodule CargoShipping.CargoLifecycleScenarioTest do
  use CargoShipping.DataCase

  require Logger

  alias CargoShipping.{CargoBookings, CargoBookingService, HandlingEventService, VoyageService}
  alias CargoShipping.CargoBookings.{Delivery, Itinerary}

  import CargoShipping.ItinerariesFixtures

  @tag hibernate_data: :all
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

    # The cargo is then assigned to the selected route, described by an itinerary.

    itineraries = CargoBookingService.possible_routes_for_cargo(cargo)
    refute Enum.empty?(itineraries)
    itinerary = select_prefered_itinerary(itineraries)
    {:ok, cargo} = CargoBookings.update_cargo_for_new_itinerary(cargo, itinerary)

    Logger.error("52 after reroute")
    Itinerary.debug_itinerary(cargo.itinerary)
    Delivery.debug_delivery(cargo.delivery)

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
    assert cargo
    assert cargo.delivery.transport_status == :IN_PORT
    assert cargo.delivery.last_known_location == "CNHKG"

    ## Next event: Load onto voyage in Hong Kong

    current_leg = Itinerary.find_leg(:LOAD, cargo.itinerary, "CNHKG")
    voyage_number = VoyageService.get_voyage_number_for_id!(current_leg.voyage_id)
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

    {:error, changeset} = HandlingEventService.register_handling_event(handling_params)
    assert changeset.errors[:voyage_number] == {"is invalid", []}
    assert changeset.errors[:location] == {"is invalid", []}

    ## (Incorrectly) unload cargo in Tokyo.

    handling_params = %{
      completed_at: ~U[2009-03-05 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: voyage_number,
      location: "JPTYO",
      event_type: :UNLOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # TODO: Verify that :cargo_misdirected event was received

    # Check current state - cargo is misdirected!
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.transport_status == :IN_PORT
    refute cargo.delivery.current_voyage_id
    assert cargo.delivery.last_known_location == "JPTYO"
    assert cargo.delivery.misdirected?
    refute cargo.delivery.next_expected_activity

    ## Cargo needs to be rerouted

    # TODO: Cleaner reroute from "earliest location from where the
    # new route originates".

    # Specify a new route, this time from Tokyo (where it was
    # incorrectly unloaded) to Stockholm.

    from_tokyo = %{
      origin: "JPTYO",
      destination: "SESTO",
      arrival_deadline: arrival_deadline
    }

    {:ok, cargo} = CargoBookings.update_cargo_for_new_route(cargo, from_tokyo)

    assert cargo.delivery.routing_status == :MISROUTED
    refute cargo.delivery.next_expected_activity

    # Repeat procedure of selecting one out of a number of possible
    # routes satisfying the route spec.

    # itineraries = CargoBookingService.possible_routes_for_cargo(cargo)
    # refute Enum.empty?(itineraries)

    # Use a predefined itinerary for the rest of the test
    # that uses legs from the "V300" and "V400" voyages.
    itinerary = jptok_deham_sesto_itinerary()
    {:ok, cargo} = CargoBookings.update_cargo_for_new_itinerary(cargo, itinerary)

    # New itinerary should satisfy new route
    assert cargo.delivery.routing_status == :ROUTED

    # TODO: We aren't properly handling the fact that after a reroute,
    # the cargo isn't misdirected anymore.

    # refute cargo.delivery.misdirected?
    # assert cargo.delivery.next_expected_activity.event_type == :LOAD
    # assert cargo.delivery.next_expected_activity.location == "JPTYO"

    ## Cargo has been rerouted, shipping continues

    # Load in Tokyo

    handling_params = %{
      completed_at: ~U[2009-03-08 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V300",
      location: "JPTYO",
      event_type: :LOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    v300 = VoyageService.get_voyage_id_for_number!("V300")
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.current_voyage_id == v300
    assert cargo.delivery.last_known_location == "JPTYO"
    assert cargo.delivery.transport_status == :ONBOARD_CARRIER
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :UNLOAD
    assert cargo.delivery.next_expected_activity.location == "DEHAM"
    assert cargo.delivery.next_expected_activity.voyage_id == v300

    # Unload in Hamburg

    handling_params = %{
      completed_at: ~U[2009-03-12 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V300",
      location: "DEHAM",
      event_type: :UNLOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    v400 = VoyageService.get_voyage_id_for_number!("V400")
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    refute cargo.delivery.current_voyage_id
    assert cargo.delivery.last_known_location == "DEHAM"
    assert cargo.delivery.transport_status == :IN_PORT
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :LOAD
    assert cargo.delivery.next_expected_activity.location == "DEHAM"
    assert cargo.delivery.next_expected_activity.voyage_id == v400

    # Load in Hamburg

    handling_params = %{
      completed_at: ~U[2009-03-14 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V400",
      location: "DEHAM",
      event_type: :LOAD
    }

    {:ok, _event} = HandlingEventService.register_handling_event(handling_params)

    # Wait for event bus
    Process.sleep(500)

    # Check current state - should be ok
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    assert cargo.delivery.current_voyage_id == v400
    assert cargo.delivery.last_known_location == "DEHAM"
    assert cargo.delivery.transport_status == :ONBOARD_CARRIER
    refute cargo.delivery.misdirected?
    assert cargo.delivery.next_expected_activity.event_type == :UNLOAD
    assert cargo.delivery.next_expected_activity.location == "SESTO"
    assert cargo.delivery.next_expected_activity.voyage_id == v400

    # Unload in Stockholm

    handling_params = %{
      completed_at: ~U[2009-03-15 00:00:00Z],
      tracking_id: tracking_id,
      voyage_number: "V400",
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
      completed_at: ~U[2009-03-15 00:00:00Z],
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

  # TODO: Find an itinerary that matches our route, rather than
  # just building random ones.
  defp select_prefered_itinerary(itineraries), do: List.first(itineraries)
end

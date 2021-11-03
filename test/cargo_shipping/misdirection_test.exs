defmodule CargoShipping.MisdirectionTest do
  use CargoShipping.DataCase

  require Logger

  alias CargoShipping.{CargoBookings, HandlingEventService, VoyagePlans, VoyageService}
  alias CargoShipping.CargoBookings.Itinerary
  alias CargoShipping.VoyagePlans.VoyageBuilder

  @base_time DateTime.utc_now() |> Timex.beginning_of_day() |> Timex.to_datetime()

  setup do
    {:ok, voyage01} =
      VoyageBuilder.init("TEST01", "SESTO")
      |> VoyageBuilder.add_movement("FIHEL", ts(1), ts(2))
      |> VoyageBuilder.add_movement("DEHAM", ts(3), ts(4))
      |> VoyageBuilder.add_movement("CNHKG", ts(5), ts(6))
      |> VoyageBuilder.add_movement("JPTYO", ts(7), ts(8))
      |> VoyageBuilder.build()
      |> VoyagePlans.create_voyage()

    {:ok, voyage02} =
      VoyageBuilder.init("TEST02", "USCHI")
      |> VoyageBuilder.add_movement("USNYC", ts(9), ts(10))
      |> VoyageBuilder.add_movement("DEHAM", ts(11), ts(12))
      |> VoyageBuilder.add_movement("NLRTM", ts(13), ts(14))
      |> VoyageBuilder.add_movement("SEGOT", ts(15), ts(16))
      |> VoyageBuilder.build()
      |> VoyagePlans.create_voyage()

    {:ok, voyage03} =
      VoyageBuilder.init("TEST03", "SEGOT")
      |> VoyageBuilder.add_movement("SESTO", ts(17), ts(18))
      |> VoyageBuilder.add_movement("FIHEL", ts(19), ts(20))
      |> VoyageBuilder.add_movement("DEHAM", ts(21), ts(22))
      |> VoyageBuilder.add_movement("NLRTM", ts(23), ts(24))
      |> VoyageBuilder.add_movement("CNHGH", ts(25), ts(26))
      |> VoyageBuilder.build()
      |> VoyagePlans.create_voyage()

    itinerary =
      [
        %{
          voyage_id: voyage01.id,
          load_location: "SESTO",
          unload_location: "DEHAM",
          load_time: ts(1),
          unload_time: ts(4),
          status: :NOT_LOADED
        },
        %{
          voyage_id: voyage02.id,
          load_location: "DEHAM",
          unload_location: "NLRTM",
          load_time: ts(11),
          unload_time: ts(14),
          status: :NOT_LOADED
        },
        %{
          voyage_id: voyage03.id,
          load_location: "NLRTM",
          unload_location: "CNHGH",
          load_time: ts(23),
          unload_time: ts(26),
          status: :NOT_LOADED
        }
      ]
      |> Itinerary.new()

    {:ok, cargo} =
      CargoBookings.create_cargo(%{
        tracking_id: "TST442",
        origin: "SESTO",
        route_specification: %{
          origin: "SESTO",
          destination: "CNHGH",
          earliest_departure: ts(0),
          arrival_deadline: ts(30)
        },
        itinerary: itinerary
      })

    %{cargo: cargo}
  end

  describe "re-routes an unexpected :RECEIVE" do
    test "with full itinerary match", %{cargo: _cargo} do
      # Simulate an unexpected RECEIVE at FIHEL
      handling_report = %{
        event_type: :RECEIVE,
        tracking_id: "TST442",
        voyage_number: "TEST01",
        location: "FIHEL",
        completed_at: ts(3)
      }

      cargo = post_report_and_get_cargo(handling_report)
      # itinerary on voyage TEST01 from FIHEL (ACTUAL) to DEHAM - NOT_LOADED
      # delivery TST442 ROUTED IN_PORT MISDIRECTED at FIHEL
      {new_route_spec, new_origin?, patch_uncompleted_leg?} =
        CargoBookings.get_remaining_route_specification(cargo)

      assert new_origin?
      assert new_route_spec
      assert new_route_spec.origin == "FIHEL"
      assert new_route_spec.destination == "CNHGH"

      new_itinerary =
        Itinerary.internal_itinerary_for_route_specification(cargo.itinerary, new_route_spec)

      assert new_itinerary
      assert Itinerary.initial_departure_location(new_itinerary) == "FIHEL"
      assert Itinerary.final_arrival_location(new_itinerary) == "CNHGH"
      refute patch_uncompleted_leg?

      merged_itinerary =
        CargoBookings.merge_itinerary(cargo.itinerary, new_itinerary, patch_uncompleted_leg?)

      assert Enum.count(merged_itinerary.legs) == 1

      final_route_spec =
        Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

      assert Itinerary.satisfies?(merged_itinerary, final_route_spec)

      params = CargoBookings.derived_routing_params(cargo, final_route_spec, merged_itinerary)
      update_and_get_cargo(cargo, params)
    end

    test "with partial itinerary match", %{cargo: _cargo} do
      # Simulate an unexpected RECEIVE at USNYC
      handling_report = %{
        event_type: :RECEIVE,
        tracking_id: "TST442",
        voyage_number: "TEST01",
        location: "USNYC",
        completed_at: ts(9)
      }

      cargo = post_report_and_get_cargo(handling_report)
      # itinerary on voyage TEST01 from USNYC (ACTUAL) to DEHAM - NOT_LOADED
      # delivery TST442 ROUTED IN_PORT MISDIRECTED at USNYC
      {new_route_spec, new_origin?, patch_uncompleted_leg?} =
        CargoBookings.get_remaining_route_specification(cargo)

      assert new_origin?
      assert new_route_spec
      assert new_route_spec.origin == "USNYC"
      assert new_route_spec.destination == "CNHGH"

      new_itinerary =
        Itinerary.internal_itinerary_for_route_specification(cargo.itinerary, new_route_spec)

      assert new_itinerary
      assert Itinerary.initial_departure_location(new_itinerary) == "USNYC"
      assert Itinerary.final_arrival_location(new_itinerary) == "CNHGH"
      refute patch_uncompleted_leg?

      merged_itinerary =
        CargoBookings.merge_itinerary(cargo.itinerary, new_itinerary, patch_uncompleted_leg?)

      assert Enum.count(merged_itinerary.legs) == 2

      final_route_spec =
        Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

      assert Itinerary.satisfies?(merged_itinerary, final_route_spec)

      params = CargoBookings.derived_routing_params(cargo, final_route_spec, merged_itinerary)
      update_and_get_cargo(cargo, params)
    end
  end

  describe "re-routes an unexpected :UNLOAD" do
    test "with full itinerary match", %{cargo: _cargo} do
      # Simulate an unexpected UNLOAD at FIHEL
      handling_report = %{
        event_type: :UNLOAD,
        tracking_id: "TST442",
        voyage_number: "TEST01",
        location: "FIHEL",
        completed_at: ts(3)
      }

      cargo = post_report_and_get_cargo(handling_report)
      # itinerary on voyage TEST01 from SESTO to FIHEL (ACTUAL) - COMPLETED
      # delivery TST442 ROUTED IN_PORT MISDIRECTED at FIHEL

      {new_route_spec, new_origin?, patch_uncompleted_leg?} =
        CargoBookings.get_remaining_route_specification(cargo)

      assert new_origin?
      assert new_route_spec
      assert new_route_spec.origin == "FIHEL"
      assert new_route_spec.destination == "CNHGH"

      new_itinerary =
        Itinerary.internal_itinerary_for_route_specification(cargo.itinerary, new_route_spec)

      assert new_itinerary
      assert Itinerary.initial_departure_location(new_itinerary) == "FIHEL"
      assert Itinerary.final_arrival_location(new_itinerary) == "CNHGH"
      refute patch_uncompleted_leg?

      merged_itinerary =
        CargoBookings.merge_itinerary(cargo.itinerary, new_itinerary, patch_uncompleted_leg?)

      assert Enum.count(merged_itinerary.legs) == 2

      final_route_spec =
        Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

      assert Itinerary.satisfies?(merged_itinerary, final_route_spec)

      params = CargoBookings.derived_routing_params(cargo, final_route_spec, merged_itinerary)
      update_and_get_cargo(cargo, params)
    end

    test "with partial itinerary match", %{cargo: _cargo} do
      # Simulate an unexpected UNLOAD at USNYC
      handling_report = %{
        event_type: :UNLOAD,
        tracking_id: "TST442",
        voyage_number: "TEST01",
        location: "USNYC",
        completed_at: ts(3)
      }

      cargo = post_report_and_get_cargo(handling_report)
      # itinerary on voyage TEST01 from SESTO to USNYC (ACTUAL) - COMPLETED
      # delivery TST442 ROUTED IN_PORT MISDIRECTED at USNYC

      {new_route_spec, new_origin?, patch_uncompleted_leg?} =
        CargoBookings.get_remaining_route_specification(cargo)

      assert new_origin?
      assert new_route_spec
      assert new_route_spec.origin == "USNYC"
      assert new_route_spec.destination == "CNHGH"

      new_itinerary =
        Itinerary.internal_itinerary_for_route_specification(cargo.itinerary, new_route_spec)

      assert new_itinerary
      assert Itinerary.initial_departure_location(new_itinerary) == "USNYC"
      assert Itinerary.final_arrival_location(new_itinerary) == "CNHGH"
      refute patch_uncompleted_leg?

      merged_itinerary =
        CargoBookings.merge_itinerary(cargo.itinerary, new_itinerary, patch_uncompleted_leg?)

      assert Enum.count(merged_itinerary.legs) == 3

      final_route_spec =
        Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

      assert Itinerary.satisfies?(merged_itinerary, final_route_spec)

      params = CargoBookings.derived_routing_params(cargo, final_route_spec, merged_itinerary)
      update_and_get_cargo(cargo, params)
    end
  end

  describe "re-routes an unexpected :LOAD" do
    test "with full itinerary match", %{cargo: _cargo} do
      # Simulate an unexpected LOAD at FIHEL
      handling_report = %{
        event_type: :LOAD,
        tracking_id: "TST442",
        voyage_number: "TEST01",
        location: "FIHEL",
        completed_at: ts(3)
      }

      cargo = post_report_and_get_cargo(handling_report)
      # itinerary on voyage TEST01 from FIHEL (ACTUAL) to DEHAM - ONBOARD_CARRIER
      # delivery TST442 ROUTED ONBOARD_CARRIER MISDIRECTED from FIHEL on voyage TEST01
      {new_route_spec, new_origin?, patch_uncompleted_leg?} =
        CargoBookings.get_remaining_route_specification(cargo)

      assert new_origin?
      assert new_route_spec
      assert new_route_spec.origin == "FIHEL"
      assert new_route_spec.destination == "CNHGH"

      new_itinerary =
        Itinerary.internal_itinerary_for_route_specification(cargo.itinerary, new_route_spec)

      assert new_itinerary
      assert Itinerary.initial_departure_location(new_itinerary) == "FIHEL"
      assert Itinerary.final_arrival_location(new_itinerary) == "CNHGH"
      assert patch_uncompleted_leg?

      merged_itinerary =
        CargoBookings.merge_itinerary(cargo.itinerary, new_itinerary, patch_uncompleted_leg?)

      assert Enum.count(merged_itinerary.legs) == 1

      final_route_spec =
        Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

      assert Itinerary.satisfies?(merged_itinerary, final_route_spec)

      params = CargoBookings.derived_routing_params(cargo, final_route_spec, merged_itinerary)
      update_and_get_cargo(cargo, params)
    end

    test "with partial itinerary match", %{cargo: _cargo} do
      # Simulate an unexpected LOAD at USNYC
      handling_report = %{
        event_type: :LOAD,
        tracking_id: "TST442",
        voyage_number: "TEST01",
        location: "USNYC",
        completed_at: ts(9)
      }

      cargo = post_report_and_get_cargo(handling_report)
      # itinerary on voyage TEST01 from USNYC (ACTUAL) to DEHAM - ONBOARD_CARRIER
      # delivery TST442 ROUTED ONBOARD_CARRIER MISDIRECTED from USNYC on voyage TEST01
      {new_route_spec, new_origin?, patch_uncompleted_leg?} =
        CargoBookings.get_remaining_route_specification(cargo)

      assert new_origin?
      assert new_route_spec
      assert new_route_spec.origin == "USNYC"
      assert new_route_spec.destination == "CNHGH"

      new_itinerary =
        Itinerary.internal_itinerary_for_route_specification(cargo.itinerary, new_route_spec)

      assert new_itinerary
      assert Itinerary.initial_departure_location(new_itinerary) == "USNYC"
      assert Itinerary.final_arrival_location(new_itinerary) == "CNHGH"
      assert patch_uncompleted_leg?

      merged_itinerary =
        CargoBookings.merge_itinerary(cargo.itinerary, new_itinerary, patch_uncompleted_leg?)

      assert Enum.count(merged_itinerary.legs) == 2

      final_route_spec =
        Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

      assert Itinerary.satisfies?(merged_itinerary, final_route_spec)

      params = CargoBookings.derived_routing_params(cargo, final_route_spec, merged_itinerary)
      update_and_get_cargo(cargo, params)
    end
  end

  defp post_report_and_get_cargo(params) do
    {:ok, _event} = HandlingEventService.register_handling_event(params)
    Process.sleep(100)
    CargoBookings.get_cargo_by_tracking_id!("TST442")
  end

  defp update_and_get_cargo(cargo, params) do
    {:ok, _cargo} = CargoBookings.update_cargo(cargo, params)
    Process.sleep(100)
    CargoBookings.get_cargo_by_tracking_id!("TST442")
  end

  defp ts(hours) do
    DateTime.add(@base_time, hours * 3600, :second)
  end
end

defmodule CargoShipping.ItineraryTest do
  use CargoShipping.DataCase

  require Logger

  alias CargoShipping.{VoyagePlans, VoyageService}
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

    %{itinerary: itinerary}
  end

  test "finds routes for unexpected :RECEIVE", %{itinerary: itinerary} do
    handling_event = %{
      event_type: :RECEIVE,
      voyage_id: VoyageService.get_voyage_id_for_number("TEST01"),
      location: "FIHEL",
      completed_at: ts(2)
    }

    {:error, message, updated_itinerary} =
      Itinerary.matches_handling_event(itinerary, handling_event, true)

    assert message == "no match for RECEIVE at FIHEL (scope: first)"
    first_leg = Itinerary.initial_leg(updated_itinerary)
    assert first_leg.actual_load_location == "FIHEL"
    assert first_leg.status == :NOT_LOADED
  end

  test "finds routes for unexpected :LOAD", %{itinerary: itinerary} do
    handling_event = %{
      event_type: :LOAD,
      voyage_id: VoyageService.get_voyage_id_for_number("TEST01"),
      location: "FIHEL",
      completed_at: ts(2)
    }

    {:error, message, updated_itinerary} =
      Itinerary.matches_handling_event(itinerary, handling_event, true)

    assert message == "no match for LOAD at FIHEL on voyage TEST01 (scope: first_uncompleted)"
    first_leg = Itinerary.initial_leg(updated_itinerary)
    assert first_leg.actual_load_location == "FIHEL"
    assert first_leg.status == :ONBOARD_CARRIER
  end

  test "finds routes for unexpected :UNLOAD", %{itinerary: itinerary} do
    handling_event = %{
      event_type: :UNLOAD,
      voyage_id: VoyageService.get_voyage_id_for_number("TEST01"),
      location: "FIHEL",
      completed_at: ts(2)
    }

    {:error, message, updated_itinerary} =
      Itinerary.matches_handling_event(itinerary, handling_event, true)

    assert message == "no match for UNLOAD at FIHEL on voyage TEST01 (scope: first_uncompleted)"
    first_leg = Itinerary.initial_leg(updated_itinerary)
    assert first_leg.actual_unload_location == "FIHEL"
    assert first_leg.status == :COMPLETED
  end

  test "splits legs correctly", %{itinerary: %{legs: legs}} do
    test_itinerary =
      Enum.zip([legs, [:COMPLETED, :SKIPPED, :NOT_LOADED]])
      |> Enum.map(fn {leg, status} -> Map.from_struct(leg) |> Map.put(:status, status) end)
      |> Itinerary.new()

    assert Itinerary.last_completed_index(test_itinerary) == 1

    {completed, uncompleted} = Itinerary.split_completed_legs(test_itinerary)
    assert Enum.count(completed) == 2
    assert Enum.count(uncompleted) == 1
  end

  test "finds internal re-route", %{itinerary: %{legs: legs}} do
    test_itinerary =
      Enum.zip([legs, [:COMPLETED, :NOT_LOADED, :NOT_LOADED]])
      |> Enum.map(fn {leg, status} -> Map.from_struct(leg) |> Map.put(:status, status) end)
      |> Itinerary.new()

    assert Itinerary.last_completed_index(test_itinerary) == 0

    # Simulate an unexpected LOAD at FIHEL
    route_specification = %{
      origin: "FIHEL",
      destination: "CNHGH",
      earliest_departure: ts(5),
      arrival_deadline: ts(26)
    }

    reroute_itinerary =
      Itinerary.internal_itinerary_for_route_specification(test_itinerary, route_specification)

    assert reroute_itinerary
    assert Enum.count(reroute_itinerary.legs) == 1
    [leg] = reroute_itinerary.legs
    assert leg.load_location == "FIHEL"
    assert leg.unload_location == "CNHGH"
    assert VoyageService.get_voyage_number_for_id(leg.voyage_id) == "TEST03"
  end

  defp ts(hours) do
    DateTime.add(@base_time, hours * 3600, :second)
  end
end

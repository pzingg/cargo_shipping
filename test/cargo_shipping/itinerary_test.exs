defmodule CargoShipping.ItineraryTest do
  use CargoShipping.DataCase

  alias CargoShipping.{VoyagePlans, VoyageService}
  alias CargoShipping.CargoBookings.Itinerary
  alias CargoShipping.VoyagePlans.VoyageBuilder

  @base_time DateTime.utc_now() |> Timex.beginning_of_day() |> Timex.to_datetime()

  setup do
    {:ok, voyage0101} =
      VoyageBuilder.init("0101", "SESTO")
      |> VoyageBuilder.add_movement("FIHEL", ts(1), ts(2))
      |> VoyageBuilder.add_movement("DEHAM", ts(1), ts(2))
      |> VoyageBuilder.add_movement("CNHKG", ts(1), ts(2))
      |> VoyageBuilder.add_movement("JPTYO", ts(1), ts(2))
      |> VoyageBuilder.build()
      |> VoyagePlans.create_voyage()

    {:ok, voyage0202} =
      VoyageBuilder.init("0202", "USCHI")
      |> VoyageBuilder.add_movement("USNYC", ts(1), ts(2))
      |> VoyageBuilder.add_movement("DEHAM", ts(1), ts(2))
      |> VoyageBuilder.add_movement("NLRTM", ts(1), ts(2))
      |> VoyageBuilder.add_movement("SEGOT", ts(1), ts(2))
      |> VoyageBuilder.build()
      |> VoyagePlans.create_voyage()

    {:ok, voyage0303} =
      VoyageBuilder.init("0303", "SEGOT")
      |> VoyageBuilder.add_movement("SESTO", ts(1), ts(2))
      |> VoyageBuilder.add_movement("FIHEL", ts(1), ts(2))
      |> VoyageBuilder.add_movement("DEHAM", ts(1), ts(2))
      |> VoyageBuilder.add_movement("NLRTM", ts(1), ts(2))
      |> VoyageBuilder.add_movement("CNHGH", ts(1), ts(2))
      |> VoyageBuilder.build()
      |> VoyagePlans.create_voyage()

    itinerary =
      [
        %{
          voyage_id: voyage0101.id,
          load_location: "SESTO",
          unload_location: "DEHAM",
          load_time: ts(1),
          unload_time: ts(2),
          status: :NOT_LOADED
        },
        %{
          voyage_id: voyage0202.id,
          load_location: "DEHAM",
          unload_location: "NLRTM",
          load_time: ts(3),
          unload_time: ts(4),
          status: :NOT_LOADED
        },
        %{
          voyage_id: voyage0303.id,
          load_location: "NLRTM",
          unload_location: "CNHGH",
          load_time: ts(5),
          unload_time: ts(6),
          status: :NOT_LOADED
        }
      ]
      |> Itinerary.new()

    %{itinerary: itinerary}
  end

  test "finds routes for unexpected :LOAD", %{itinerary: itinerary} do
    handling_event = %{
      event_type: :LOAD,
      voyage_id: VoyageService.get_voyage_id_for_number!("0101"),
      location: "FIHEL"
    }

    {:error, message, _info} = Itinerary.matches_handling_event(itinerary, handling_event)
    assert message == "LOAD at FIHEL does not match any load location of voyage 0101"
  end

  test "finds routes for unexpected :UNLOAD", %{itinerary: itinerary} do
    handling_event = %{
      event_type: :UNLOAD,
      voyage_id: VoyageService.get_voyage_id_for_number!("0101"),
      location: "FIHEL"
    }

    {:error, message, _info} = Itinerary.matches_handling_event(itinerary, handling_event)
    assert message == "UNLOAD at FIHEL does not match any unload location of voyage 0101"
  end

  test "splits legs correctly", %{itinerary: %{legs: legs}} do
    new_itinerary = %{
      legs:
        Enum.zip([legs, [:COMPLETED, :SKIPPED, :NOT_LOADED]])
        |> Enum.map(fn {leg, status} -> Map.put(leg, :status, status) end)
    }

    assert Itinerary.first_uncompleted_index(new_itinerary) == 2
    {completed, uncompleted} = Itinerary.split_completed_legs(new_itinerary)
    assert Enum.count(completed) == 2
    assert Enum.count(uncompleted) == 1
  end

  defp ts(hours) do
    DateTime.add(@base_time, hours * 3600, :second)
  end
end

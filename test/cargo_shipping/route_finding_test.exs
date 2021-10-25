defmodule CargoShipping.RouteFindingTest do
  use CargoShipping.DataCase

  describe "finds shortest path from" do
    @tag hibernate_data: :voyages
    test "CNHKG to CNSHA" do
      itineraries = find_paths("CNHKG", "CNSHA")
      shortest = List.first(itineraries)

      refute is_nil(shortest)
      assert Enum.count(shortest.legs) == 3
      first_leg = List.first(shortest.legs)
      last_leg = List.last(shortest.legs)
      assert first_leg.load_location == "CNHKG"
      assert last_leg.unload_location == "CNSHA"
    end

    @tag hibernate_data: :voyages
    test "USNYC to CNSHA" do
      itineraries = find_paths("USNYC", "CNSHA")
      shortest = List.first(itineraries)

      refute is_nil(shortest)
      assert Enum.count(shortest.legs) == 5
      first_leg = List.first(shortest.legs)
      last_leg = List.last(shortest.legs)
      assert first_leg.load_location == "USNYC"
      assert last_leg.unload_location == "CNSHA"
    end
  end

  describe "finds no path from" do
    @tag hibernate_data: :voyages
    test "from CNSHA to CNHKG" do
      itineraries = find_paths("CNSHA", "CNHKG")
      shortest = List.first(itineraries)
      assert is_nil(shortest)
    end
  end

  defp find_paths(from, to) do
    route_specification = %{
      origin: from,
      destination: to,
      arrival_deadline: DateTime.utc_now()
    }

    CargoShipping.CargoBookingService.routes_for_specification(route_specification,
      algorithm: :libgraph
    )
  end
end

defmodule CargoShipping.RouteFindingTest do
  use CargoShipping.DataCase

  require Logger

  describe "finds shortest path from" do
    alias CargoShipping.CargoBookings.Itinerary

    @tag hibernate_data: :voyages
    test "CNHKG to CNSHA" do
      itineraries = find_paths("CNHKG", "CNSHA")
      debug_itineraries(itineraries, "CNHKG", "CNSHA")
      shortest = List.first(itineraries)

      refute is_nil(shortest)
      assert Enum.count(shortest.itinerary.legs) == 11
      Itinerary.debug_itinerary(shortest.itinerary)

      first_leg = List.first(shortest.itinerary.legs)
      last_leg = List.last(shortest.itinerary.legs)
      assert first_leg.load_location == "CNHKG"
      assert last_leg.unload_location == "CNSHA"
    end

    @tag hibernate_data: :voyages
    test "USNYC to CNSHA" do
      itineraries = find_paths("USNYC", "CNSHA")
      debug_itineraries(itineraries, "USNYC", "CNSHA")
      shortest = List.first(itineraries)

      refute is_nil(shortest)
      assert Enum.count(shortest.itinerary.legs) == 7
      Itinerary.debug_itinerary(shortest.itinerary)

      first_leg = List.first(shortest.itinerary.legs)
      last_leg = List.last(shortest.itinerary.legs)
      assert first_leg.load_location == "USNYC"
      assert last_leg.unload_location == "CNSHA"
    end
  end

  describe "finds no path from" do
    @tag hibernate_data: :voyages
    test "from CNSHA to CNHKG" do
      itineraries = find_paths("CNSHA", "CNHKG")
      debug_itineraries(itineraries, "CNSHA", "CNHKG")
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

    CargoShipping.CargoBookingService.routes_for_specification(
      route_specification,
      algorithm: :libgraph,
      find: :all
    )
  end

  def debug_itineraries(itineraries, from, to) do
    Logger.error("#{Enum.count(itineraries)} itineraries from #{from} to #{to}:")

    if !Enum.empty?(itineraries) do
      limit = min(5, Enum.count(itineraries))

      for i <- 1..limit do
        %{itinerary: it, cost: cost} = Enum.at(itineraries, i - 1)
        Logger.error("Itinerary #{i}, cost #{cost}, #{Enum.count(it.legs)} legs")
      end
    end
  end
end

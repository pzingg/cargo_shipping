defmodule CargoShipping.ItinerariesFixtures do
  @moduledoc false

  alias CargoShipping.VoyageService
  alias CargoShipping.CargoBookings.Itinerary

  def jptok_deham_sesto_itinerary() do
    v300 = VoyageService.get_voyage_id_for_number("V300")
    v400 = VoyageService.get_voyage_id_for_number("V400")

    Itinerary.new([
      %{
        voyage_id: v300,
        load_location: "JPTYO",
        unload_location: "DEHAM",
        load_time: ~U[2009-03-08 00:00:00Z],
        unload_time: ~U[2009-03-12 00:00:00Z],
        status: :NOT_LOADED
      },
      %{
        voyage_id: v400,
        load_location: "DEHAM",
        unload_location: "SESTO",
        load_time: ~U[2009-03-14 00:00:00Z],
        unload_time: ~U[2009-03-15 00:00:00Z],
        status: :NOT_LOADED
      }
    ])
  end
end

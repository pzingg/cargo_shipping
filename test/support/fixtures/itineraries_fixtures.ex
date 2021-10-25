defmodule CargoShipping.ItinerariesFixtures do
  alias CargoShipping.VoyageService

  def jptok_deham_sesto_itinerary() do
    v300 = VoyageService.get_voyage_id_for_number!("V300")
    v400 = VoyageService.get_voyage_id_for_number!("V400")

    %{
      legs: [
        %{
          voyage_id: v300,
          load_location: "JPTOK",
          unload_location: "DEHAM",
          load_time: ~U[2009-03-08 00:00:00Z],
          unload_time: ~U[2009-03-12 00:00:00Z]
        },
        %{
          voyage_id: v400,
          load_location: "DEHAM",
          unload_location: "SESTO",
          load_time: ~U[2009-03-14 00:00:00Z],
          unload_time: ~U[2009-03-15 00:00:00Z]
        }
      ]
    }
  end
end

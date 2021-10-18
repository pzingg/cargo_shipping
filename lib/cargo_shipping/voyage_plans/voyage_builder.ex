defmodule CargoShipping.VoyagePlans.VoyageBuilder do
  @moduledoc """
  Convenience methods for creating Voyage aggregates.
  """

  def init(voyage_number, departure_location) do
    %{voyage_number: voyage_number, departure_location: departure_location, schedule_items: []}
  end

  def add_movement(state, arrival_location, departure_time, arrival_time) do
    new_movement = %{
      departure_location: state.departure_location,
      arrival_location: arrival_location,
      departure_time: departure_time,
      arrival_time: arrival_time
    }

    # Next departure location is the same as this arrival location
    state
    |> Map.put(:departure_location, arrival_location)
    |> Map.put(:schedule_items, [new_movement | state.schedule_items])
  end

  def build(%{voyage_number: voyage_number, schedule_items: movements}) do
    %{
      voyage_number: voyage_number,
      schedule_items: Enum.reverse(movements)
    }
  end
end

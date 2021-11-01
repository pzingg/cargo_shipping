defmodule CargoShipping.VoyagePlansFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CargoShipping.VoyagePlans` context.
  """

  @voyage_number "V0042"

  def voyage_fixture_number(), do: @voyage_number

  @doc """
  Generate a voyage.
  """
  def voyage_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        voyage_number: @voyage_number,
        schedule_items: [
          %{
            departure_location: "DEHAM",
            arrival_location: "CNSHA",
            departure_time: ~U[2015-01-24 23:50:07Z],
            arrival_time: ~U[2015-02-23 23:50:07Z]
          },
          %{
            departure_location: "CNSHA",
            arrival_location: "JPTYO",
            departure_time: ~U[2015-02-24 23:50:07Z],
            arrival_time: ~U[2015-03-23 23:50:07Z]
          },
          %{
            departure_location: "JPTYO",
            arrival_location: "AUMEL",
            departure_time: ~U[2015-03-24 23:50:07Z],
            arrival_time: ~U[2015-04-23 23:50:07Z]
          }
        ]
      })

    case CargoShipping.VoyagePlans.get_voyage_by_number(attrs.voyage_number) do
      nil ->
        {:ok, voyage} = CargoShipping.VoyagePlans.create_voyage(attrs)
        voyage

      voyage ->
        voyage
    end
  end
end

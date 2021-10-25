defmodule CargoShipping.VoyagePlansFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CargoShipping.VoyagePlans` context.
  """

  def schedule_fixture() do
    [
      %{
        departure_location: "DEHAM",
        arrival_location: "CNSHA",
        departure_time: ~U[2015-01-23 23:50:07Z],
        arrival_time: ~U[2015-02-23 23:50:07Z]
      },
      %{
        departure_location: "CNSHA",
        arrival_location: "JPTYO",
        departure_time: ~U[2015-02-24 23:50:07Z],
        arrival_time: ~U[2015-03-23 23:50:07Z]
      }
    ]
  end

  @doc """
  Generate a voyage.
  """
  def voyage_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        voyage_number: "V42",
        schedule_items: schedule_fixture()
      })

    {:ok, voyage} = CargoShipping.VoyagePlans.create_voyage(attrs)

    voyage
  end
end

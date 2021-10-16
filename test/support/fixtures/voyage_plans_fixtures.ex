defmodule CargoShipping.VoyagePlansFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CargoShipping.VoyagePlans` context.
  """

  def schedule_fixture() do
    [
      %{
        "departure_location" => "DEHAM",
        "arrival_location" => "CNSHA",
        "departure_time" => "2015-01-23T23:50:07Z",
        "arrival_time" => "2015-02-23T23:50:07Z"
      },
      %{
        "departure_location" => "CNSHA",
        "arrival_location" => "JPTKO",
        "departure_time" => "2015-02-24T23:50:07Z",
        "arrival_time" => "2015-03-23T23:50:07Z"
      }
    ]
  end

  @doc """
  Generate a voyage.
  """
  def voyage_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{
      "voyage_number" => 42,
      "schedule_items" => schedule_fixture()})

    {:ok, voyage} = CargoShipping.VoyagePlans.create_voyage(attrs)

    voyage
  end
end

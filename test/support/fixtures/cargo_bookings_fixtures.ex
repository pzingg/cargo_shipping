defmodule CargoShipping.CargoBookingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CargoShipping.CargoBookings` context.
  """

  require Logger

  @tracking_id "TST042"

  def route_specification_fixture() do
    %{
      origin: "DEHAM",
      destination: "AUMEL",
      earliest_departure: ~U[2015-01-01 00:00:00Z],
      arrival_deadline: ~U[2015-05-31 23:50:07Z]
    }
  end

  def itinerary_fixture() do
    voyage = CargoShipping.VoyagePlansFixtures.voyage_fixture()

    %{
      legs: [
        %{
          voyage_id: voyage.id,
          load_location: "DEHAM",
          unload_location: "CNSHA",
          load_time: ~U[2015-01-24 23:50:07Z],
          unload_time: ~U[2015-02-23 23:50:07Z],
          status: :NOT_LOADED
        },
        %{
          voyage_id: voyage.id,
          load_location: "CNSHA",
          unload_location: "AUMEL",
          load_time: ~U[2015-02-24 23:50:07Z],
          unload_time: ~U[2015-04-23 23:50:07Z],
          status: :NOT_LOADED
        }
      ]
    }
  end

  def cargo_fixture_tracking_id(), do: @tracking_id

  @doc """
  Generate a cargo.
  """
  def cargo_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        tracking_id: @tracking_id,
        origin: "DEHAM",
        route_specification: route_specification_fixture(),
        itinerary: itinerary_fixture()
      })

    try do
      CargoShipping.CargoBookings.get_cargo_by_tracking_id!(attrs.tracking_id)
    rescue
      Ecto.NoResultsError ->
        {:ok, _cargo} = CargoShipping.CargoBookings.create_cargo(attrs)
        Process.sleep(100)
        CargoShipping.CargoBookings.get_cargo_by_tracking_id!(attrs.tracking_id)
    end
  end

  @doc """
  Generate a handling_event.
  """
  def handling_event_fixture(attrs \\ %{}) do
    cargo = cargo_fixture()

    attrs =
      Enum.into(attrs, %{
        event_type: "RECEIVE",
        location: cargo.origin,
        completed_at: ~U[2015-01-24 00:00:00Z]
      })

    {:ok, handling_event} = CargoShipping.CargoBookings.create_handling_event(cargo, attrs)
    handling_event
  end
end

defmodule CargoShipping.CargoBookingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CargoShipping.CargoBookings` context.
  """

  @voyage_id UUID.uuid4()
  @last_event_id UUID.uuid4()

  def route_specification_fixture() do
    %{"origin" => "DEHAM", "destination" => "CNSHA", "arrival_deadline" => "2015-02-23T23:50:07Z"}
  end

  def itinerary_fixture() do
    %{
      "legs" => [
        %{
          "voyage_id" => @voyage_id,
          "load_location" => "DEHAM",
          "unload_location" => "CNSHA",
          "load_time" => ~U[2015-01-23 23:50:07Z],
          "unload_time" => ~U[2015-02-23 23:50:07Z]
        }
      ]
    }
  end

  def delivery_fixture() do
    %{
      "transport_status" => "UNKNOWN",
      "last_known_location" => "DEHAM",
      "current_voyage_id" => @voyage_id,
      "misdirected?" => false,
      "eta" => "2015-02-23T23:50:07Z",
      "unloaded_at_destination?" => false,
      "routing_status" => "NOT_ROUTED",
      "calculated_at" => "2015-02-01T00:00:00Z",
      "last_event_id" => @last_event_id,
      "next_expected_activity" => nil
    }
  end

  @doc """
  Generate a cargo.
  """
  def cargo_fixture(attrs \\ %{}) do
    {:ok, cargo} =
      attrs
      |> Enum.into(%{
        "tracking_id" => "some tracking_id",
        "origin" => "DEHAM",
        "route_specification" => route_specification_fixture(),
        "itinerary" => itinerary_fixture(),
        "delivery" => delivery_fixture()
      })
      |> CargoShipping.CargoBookings.create_cargo()

    cargo
  end

  @doc """
  Generate a handling_event.
  """
  def handling_event_fixture(attrs \\ %{}) do
    cargo = cargo_fixture()

    attrs =
      Enum.into(attrs, %{
        event_type: "RECEIVE",
        location: "DEHAM",
        completed_at: ~U[2021-10-14 20:32:00Z]
      })

    {:ok, handling_event} = CargoShipping.CargoBookings.create_handling_event(cargo, attrs)

    handling_event
  end
end

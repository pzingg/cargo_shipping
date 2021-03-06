defmodule CargoShipping.CargoBookingsTest do
  use CargoShipping.DataCase

  alias CargoShipping.CargoBookings

  # TODO: Fix PostgreSQL Sandbox checkin/checkout errors.

  describe "cargos" do
    alias CargoShipping.CargoBookingService
    alias CargoShippingSchemas.Cargo

    import CargoShipping.CargoBookingsFixtures
    import CargoShipping.VoyagePlansFixtures

    @invalid_attrs %{tracking_id: nil}

    test "list_cargos/0 returns all cargos" do
      cargo = cargo_fixture()
      assert CargoBookings.list_cargos() == [cargo]
    end

    test "get_cargo!/1 returns the cargo with given id" do
      cargo = cargo_fixture()
      assert CargoBookings.get_cargo!(cargo.id) == cargo
    end

    test "create_cargo/1 with valid data creates a cargo" do
      voyage = voyage_fixture()

      valid_attrs = %{
        "tracking_id" => "TST042",
        "route_specification" => %{
          "origin" => "DEHAM",
          "destination" => "AUMEL",
          "earliest_departure" => ~U[2015-01-01 00:00:00Z],
          "arrival_deadline" => ~U[2015-05-31 23:50:07Z]
        },
        "itinerary" => %{
          "legs" => [
            %{
              "voyage_id" => voyage.id,
              "load_location" => "DEHAM",
              "unload_location" => "CNSHA",
              "load_time" => ~U[2015-01-24 23:50:07Z],
              "unload_time" => ~U[2015-02-23 23:50:07Z],
              "status" => "NOT_LOADED"
            },
            %{
              "voyage_id" => voyage.id,
              "load_location" => "CNSHA",
              "unload_location" => "AUMEL",
              "load_time" => ~U[2015-02-24 23:50:07Z],
              "unload_time" => ~U[2015-04-23 23:50:07Z],
              "status" => "NOT_LOADED"
            }
          ]
        }
      }

      assert {:ok, %Cargo{} = cargo} = CargoBookingService.create_cargo(valid_attrs)
      Process.sleep(100)
      cargo = CargoBookings.get_cargo!(cargo.id)
      assert cargo.route_specification.origin == "DEHAM"
      assert cargo.tracking_id == "TST042"
    end

    test "create_cargo/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = CargoBookingService.create_cargo(@invalid_attrs)
      Process.sleep(100)
    end

    test "update_cargo/2 with valid data updates the cargo" do
      voyage = voyage_fixture()
      cargo = cargo_fixture()

      update_attrs = %{
        "route_specification" => %{
          "origin" => "CNSHA",
          "destination" => "AUMEL",
          "earliest_departure" => ~U[2015-01-01 00:00:00Z],
          "arrival_deadline" => ~U[2015-05-31 23:50:07Z]
        },
        "itinerary" => %{
          "legs" => [
            %{
              "voyage_id" => voyage.id,
              "load_location" => "CNSHA",
              "unload_location" => "AUMEL",
              "load_time" => ~U[2015-02-24 23:50:07Z],
              "unload_time" => ~U[2015-04-23 23:50:07Z],
              "status" => "NOT_LOADED"
            }
          ]
        }
      }

      assert {:ok, %Cargo{} = cargo} = CargoBookings.update_cargo(cargo, update_attrs)
      Process.sleep(100)
      cargo = CargoBookings.get_cargo!(cargo.id)
      assert cargo.route_specification.origin == "CNSHA"
    end

    test "update_cargo/2 with invalid data returns error changeset" do
      cargo = cargo_fixture()
      assert {:error, %Ecto.Changeset{}} = CargoBookings.update_cargo(cargo, @invalid_attrs)
      Process.sleep(100)
    end

    test "delete_cargo/1 deletes the cargo" do
      cargo = cargo_fixture()
      assert {:ok, %Cargo{}} = CargoBookings.delete_cargo(cargo)
      assert_raise Ecto.NoResultsError, fn -> CargoBookings.get_cargo!(cargo.id) end
    end

    test "change_cargo/1 returns a cargo changeset" do
      cargo = cargo_fixture()
      assert %Ecto.Changeset{} = CargoBookings.change_cargo(cargo)
    end
  end

  describe "handling_events" do
    alias CargoShipping.HandlingEventService
    alias CargoShippingSchemas.HandlingEvent, as: HandlingEvent_

    import CargoShipping.CargoBookingsFixtures

    @invalid_attrs %{completed_at: nil, event_type: nil}

    test "list_handling_events/0 returns all handling_events" do
      handling_event = handling_event_fixture()
      assert CargoBookings.list_handling_events() == [handling_event]
    end

    test "get_handling_event!/1 returns the handling_event with given id" do
      handling_event = handling_event_fixture()
      assert CargoBookings.get_handling_event!(handling_event.id) == handling_event
    end

    test "create_handling_event/1 with valid data creates a handling_event" do
      valid_attrs = %{
        "event_type" => "RECEIVE",
        "location" => "DEHAM",
        "completed_at" => ~U[2021-10-14 20:32:00Z]
      }

      assert {:ok, %HandlingEvent_{} = handling_event} =
               HandlingEventService.create_handling_event(cargo_fixture(), valid_attrs)

      Process.sleep(100)
      assert handling_event.event_type == :RECEIVE
      assert handling_event.completed_at == ~U[2021-10-14 20:32:00Z]
    end

    test "create_handling_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               HandlingEventService.create_handling_event(cargo_fixture(), @invalid_attrs)
    end

    test "delete_handling_event/1 deletes the handling_event" do
      handling_event = handling_event_fixture()
      assert {:ok, %HandlingEvent_{}} = CargoBookings.delete_handling_event(handling_event)

      assert_raise Ecto.NoResultsError, fn ->
        CargoBookings.get_handling_event!(handling_event.id)
      end
    end
  end
end

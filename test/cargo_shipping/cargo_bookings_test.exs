defmodule CargoShipping.CargoBookingsTest do
  use CargoShipping.DataCase

  alias CargoShipping.CargoBookings

  describe "cargos" do
    alias CargoShipping.CargoBookings.Cargo

    import CargoShipping.CargoBookingsFixtures

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
      valid_attrs = %{
        "tracking_id" => "TST042",
        "origin" => "DEHAM",
        "route_specification" => route_specification_fixture(),
        "itinerary" => itinerary_fixture(),
        "delivery" => delivery_fixture()
      }

      assert {:ok, %Cargo{} = cargo} = CargoBookings.create_cargo(valid_attrs)
      assert cargo.tracking_id == "TST042"
    end

    test "create_cargo/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = CargoBookings.create_cargo(@invalid_attrs)
    end

    test "update_cargo/2 with valid data updates the cargo" do
      cargo = cargo_fixture()

      update_attrs = %{
        "tracking_id" => "some updated tracking_id",
        "origin" => "DEHAM",
        "route_specification" => route_specification_fixture(),
        "itinerary" => itinerary_fixture(),
        "delivery" => delivery_fixture()
      }

      assert {:ok, %Cargo{} = cargo} = CargoBookings.update_cargo(cargo, update_attrs)
      assert cargo.tracking_id == "some updated tracking_id"
    end

    test "update_cargo/2 with invalid data returns error changeset" do
      cargo = cargo_fixture()
      assert {:error, %Ecto.Changeset{}} = CargoBookings.update_cargo(cargo, @invalid_attrs)
      assert cargo == CargoBookings.get_cargo!(cargo.id)
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
    alias CargoShipping.CargoBookings.HandlingEvent

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

      assert {:ok, %HandlingEvent{} = handling_event} =
               CargoBookings.create_handling_event(cargo_fixture(), valid_attrs)

      assert handling_event.event_type == :RECEIVE
      assert handling_event.completed_at == ~U[2021-10-14 20:32:00Z]
    end

    test "create_handling_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               CargoBookings.create_handling_event(cargo_fixture(), @invalid_attrs)
    end

    test "delete_handling_event/1 deletes the handling_event" do
      handling_event = handling_event_fixture()
      assert {:ok, %HandlingEvent{}} = CargoBookings.delete_handling_event(handling_event)

      assert_raise Ecto.NoResultsError, fn ->
        CargoBookings.get_handling_event!(handling_event.id)
      end
    end
  end
end

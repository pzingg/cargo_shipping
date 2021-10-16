defmodule CargoShipping.VoyagePlansTest do
  use CargoShipping.DataCase

  alias CargoShipping.VoyagePlans

  describe "voyages" do
    alias CargoShipping.VoyagePlans.Voyage

    import CargoShipping.VoyagePlansFixtures

    @invalid_attrs %{"voyage_number" => nil, "schedule_items" => nil}

    @schedule_update_attrs [
      %{
        "departure_location" => "NLRTM",
        "arrival_location" => "CNSHA",
        "departure_time" => "2016-01-23T23:50:07Z",
        "arrival_time" =>"2016-02-23T23:50:07Z"
      }
    ]

    test "list_voyages/0 returns all voyages" do
      voyage = voyage_fixture()
      assert VoyagePlans.list_voyages() == [voyage]
    end

    test "get_voyage!/1 returns the voyage with given id" do
      voyage = voyage_fixture()
      assert VoyagePlans.get_voyage!(voyage.id) == voyage
    end

    test "create_voyage/1 with valid data creates a voyage" do
      valid_attrs = %{"voyage_number" => 42, "schedule_items" => schedule_fixture()}

      assert {:ok, %Voyage{} = voyage} = VoyagePlans.create_voyage(valid_attrs)
      assert voyage.voyage_number == 42
      assert Enum.count(voyage.schedule_items) == 2
      assert hd(voyage.schedule_items).departure_location == "DEHAM"
    end

    test "create_voyage/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = VoyagePlans.create_voyage(@invalid_attrs)
    end

    test "update_voyage/2 with valid data updates the voyage" do
      voyage = voyage_fixture()
      update_attrs = %{"voyage_number" => 43, "schedule_items" => @schedule_update_attrs}

      assert {:ok, %Voyage{} = voyage} = VoyagePlans.update_voyage(voyage, update_attrs)
      assert voyage.voyage_number == 43
      assert Enum.count(voyage.schedule_items) == 1
      assert hd(voyage.schedule_items).departure_location == "NLRTM"
    end

    test "update_voyage/2 with invalid data returns error changeset" do
      voyage = voyage_fixture()
      assert {:error, %Ecto.Changeset{}} = VoyagePlans.update_voyage(voyage, @invalid_attrs)
      assert voyage == VoyagePlans.get_voyage!(voyage.id)
    end

    test "delete_voyage/1 deletes the voyage" do
      voyage = voyage_fixture()
      assert {:ok, %Voyage{}} = VoyagePlans.delete_voyage(voyage)
      assert_raise Ecto.NoResultsError, fn -> VoyagePlans.get_voyage!(voyage.id) end
    end

    test "change_voyage/1 returns a voyage changeset" do
      voyage = voyage_fixture()
      assert %Ecto.Changeset{} = VoyagePlans.change_voyage(voyage)
    end
  end
end

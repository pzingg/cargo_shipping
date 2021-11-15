defmodule CargoShipping.VoyagePlansTest do
  use CargoShipping.DataCase

  alias CargoShipping.VoyagePlans

  describe "voyages" do
    alias CargoShippingSchemas.Voyage, as: Voyage_

    import CargoShipping.VoyagePlansFixtures

    @invalid_attrs %{"voyage_number" => nil, "schedule_items" => nil}

    @schedule_update_attrs [
      %{
        "departure_location" => "NLRTM",
        "arrival_location" => "CNSHA",
        "departure_time" => ~U[2016-01-23 23:50:07Z],
        "arrival_time" => ~U[2016-02-23 23:50:07Z]
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
      valid_attrs = %{
        "voyage_number" => "V0042",
        "schedule_items" => [
          %{
            "departure_location" => "DEHAM",
            "arrival_location" => "CNSHA",
            "departure_time" => ~U[2015-01-24 23:50:07Z],
            "arrival_time" => ~U[2015-02-23 23:50:07Z]
          },
          %{
            "departure_location" => "CNSHA",
            "arrival_location" => "JPTYO",
            "departure_time" => ~U[2015-02-24 23:50:07Z],
            "arrival_time" => ~U[2015-03-23 23:50:07Z]
          },
          %{
            "departure_location" => "JPTYO",
            "arrival_location" => "AUMEL",
            "departure_time" => ~U[2015-03-24 23:50:07Z],
            "arrival_time" => ~U[2015-04-23 23:50:07Z]
          }
        ]
      }

      assert {:ok, %Voyage_{} = voyage} = VoyagePlans.create_voyage(valid_attrs)
      assert voyage.voyage_number == "V0042"
      assert Enum.count(voyage.schedule_items) == 3
      assert hd(voyage.schedule_items).departure_location == "DEHAM"
    end

    test "create_voyage/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = VoyagePlans.create_voyage(@invalid_attrs)
    end

    test "update_voyage/2 with valid data updates the voyage" do
      voyage = voyage_fixture()
      update_attrs = %{"voyage_number" => "V0043", "schedule_items" => @schedule_update_attrs}

      assert {:ok, %Voyage_{} = voyage} = VoyagePlans.update_voyage(voyage, update_attrs)
      assert voyage.voyage_number == "V0043"
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
      assert {:ok, %Voyage_{}} = VoyagePlans.delete_voyage(voyage)
      assert_raise Ecto.NoResultsError, fn -> VoyagePlans.get_voyage!(voyage.id) end
    end

    test "change_voyage/1 returns a voyage changeset" do
      voyage = voyage_fixture()
      assert %Ecto.Changeset{} = VoyagePlans.change_voyage(voyage)
    end
  end
end

defmodule CargoShipping.ReportsTest do
  use CargoShipping.DataCase

  alias CargoShipping.Reports

  describe "handling_reports" do
    alias CargoShipping.Reports.HandlingReport

    import CargoShipping.ReportsFixtures

    @invalid_attrs %{
      completed_at: nil,
      event_type: nil,
      location: nil,
      tracking_id: nil,
      voyage_number: nil
    }

    test "list_handling_reports/0 returns all handling_reports" do
      handling_report = handling_report_fixture()
      assert Reports.list_handling_reports() == [handling_report]
    end

    test "get_handling_report!/1 returns the handling_report with given id" do
      handling_report = handling_report_fixture()
      assert Reports.get_handling_report!(handling_report.id) == handling_report
    end

    test "create_handling_report/1 with valid data creates a handling_report" do
      cargo = CargoShipping.CargoBookingsFixtures.cargo_fixture()
      voyage = CargoShipping.VoyagePlansFixtures.voyage_fixture()

      valid_attrs = %{
        completed_at: ~U[2021-10-20 03:47:00Z],
        event_type: "UNLOAD",
        location: "DEHAM",
        tracking_id: cargo.tracking_id,
        voyage_number: voyage.voyage_number
      }

      assert {:ok, %HandlingReport{} = handling_report} =
               Reports.create_handling_report(valid_attrs)

      assert handling_report.completed_at == ~U[2021-10-20 03:47:00Z]
      assert handling_report.event_type == :UNLOAD
      assert handling_report.location == "DEHAM"
      assert handling_report.tracking_id == cargo.tracking_id
      assert handling_report.voyage_number == voyage.voyage_number
    end

    test "create_handling_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Reports.create_handling_report(@invalid_attrs)
    end

    test "delete_handling_report/1 deletes the handling_report" do
      handling_report = handling_report_fixture()
      assert {:ok, %HandlingReport{}} = Reports.delete_handling_report(handling_report)
      assert_raise Ecto.NoResultsError, fn -> Reports.get_handling_report!(handling_report.id) end
    end
  end
end

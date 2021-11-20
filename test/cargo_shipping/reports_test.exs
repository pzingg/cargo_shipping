defmodule CargoShipping.ReportsTest do
  use CargoShipping.DataCase

  alias CargoShipping.Reports

  describe "handling_reports" do
    alias CargoShipping.HandlingReportService
    alias CargoShippingSchemas.HandlingReport, as: HandlingReport_

    import CargoShipping.ReportsFixtures

    @invalid_attrs %{
      tracking_id: nil,
      version: nil,
      event_type: nil,
      location: nil,
      voyage_number: nil,
      completed_at: nil
    }

    test "list_handling_reports/0 returns all handling_reports" do
      handling_report = handling_report_fixture()
      assert Reports.list_handling_reports() == [handling_report]
    end

    test "get_handling_report!/1 returns the handling_report with given id" do
      handling_report = handling_report_fixture()
      assert Reports.get_handling_report!(handling_report.id) == handling_report
    end

    test "submit_report/1 with valid data creates a handling_report" do
      cargo = CargoShipping.CargoBookingsFixtures.cargo_fixture()
      voyage_number = CargoShipping.VoyagePlansFixtures.voyage_fixture_number()

      valid_attrs = %{
        tracking_id: cargo.tracking_id,
        version: cargo.version,
        event_type: "LOAD",
        location: cargo.route_specification.origin,
        voyage_number: voyage_number,
        completed_at: ~U[2021-10-20 03:47:00Z]
      }

      assert {:ok, %HandlingReport_{} = handling_report} =
               HandlingReportService.submit_report(valid_attrs)

      Process.sleep(100)

      assert handling_report.completed_at == ~U[2021-10-20 03:47:00Z]
      assert handling_report.event_type == :LOAD
      assert handling_report.location == cargo.route_specification.origin
      assert handling_report.tracking_id == cargo.tracking_id
      assert handling_report.voyage_number == voyage_number
    end

    test "submit_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = HandlingReportService.submit_report(@invalid_attrs)
      Process.sleep(100)
    end

    test "delete_handling_report/1 deletes the handling_report" do
      handling_report = handling_report_fixture()
      assert {:ok, %HandlingReport_{}} = Reports.delete_handling_report(handling_report)
      assert_raise Ecto.NoResultsError, fn -> Reports.get_handling_report!(handling_report.id) end
    end
  end
end

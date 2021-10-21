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
      valid_attrs = %{
        completed_at: ~U[2021-10-20 03:47:00Z],
        event_type: "some event_type",
        location: "some location",
        tracking_id: "some tracking_id",
        voyage_number: "some voyage_number"
      }

      assert {:ok, %HandlingReport{} = handling_report} =
               Reports.create_handling_report(valid_attrs)

      assert handling_report.completed_at == ~U[2021-10-20 03:47:00Z]
      assert handling_report.event_type == "some event_type"
      assert handling_report.location == "some location"
      assert handling_report.tracking_id == "some tracking_id"
      assert handling_report.voyage_number == "some voyage_number"
    end

    test "create_handling_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Reports.create_handling_report(@invalid_attrs)
    end

    test "update_handling_report/2 with valid data updates the handling_report" do
      handling_report = handling_report_fixture()

      update_attrs = %{
        completed_at: ~U[2021-10-21 03:47:00Z],
        event_type: "some updated event_type",
        location: "some updated location",
        tracking_id: "some updated tracking_id",
        voyage_number: "some updated voyage_number"
      }

      assert {:ok, %HandlingReport{} = handling_report} =
               Reports.update_handling_report(handling_report, update_attrs)

      assert handling_report.completed_at == ~U[2021-10-21 03:47:00Z]
      assert handling_report.event_type == "some updated event_type"
      assert handling_report.location == "some updated location"
      assert handling_report.tracking_id == "some updated tracking_id"
      assert handling_report.voyage_number == "some updated voyage_number"
    end

    test "update_handling_report/2 with invalid data returns error changeset" do
      handling_report = handling_report_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Reports.update_handling_report(handling_report, @invalid_attrs)

      assert handling_report == Reports.get_handling_report!(handling_report.id)
    end

    test "delete_handling_report/1 deletes the handling_report" do
      handling_report = handling_report_fixture()
      assert {:ok, %HandlingReport{}} = Reports.delete_handling_report(handling_report)
      assert_raise Ecto.NoResultsError, fn -> Reports.get_handling_report!(handling_report.id) end
    end

    test "change_handling_report/1 returns a handling_report changeset" do
      handling_report = handling_report_fixture()
      assert %Ecto.Changeset{} = Reports.change_handling_report(handling_report)
    end
  end
end

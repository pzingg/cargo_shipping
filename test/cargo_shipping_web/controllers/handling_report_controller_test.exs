defmodule CargoShippingWeb.HandlingReportControllerTest do
  use CargoShippingWeb.ConnCase

  import CargoShipping.ReportsFixtures

  alias CargoShipping.Reports.HandlingReport

  @invalid_attrs %{
    completed_at: nil,
    event_type: nil,
    location: nil,
    tracking_id: nil,
    voyage_number: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all handling_reports", %{conn: conn} do
      conn = get(conn, Routes.handling_report_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create handling_report" do
    test "renders handling_report when data is valid", %{conn: conn} do
      cargo = CargoShipping.CargoBookingsFixtures.cargo_fixture()
      voyage = CargoShipping.VoyagePlansFixtures.voyage_fixture()
      attrs = create_attrs(cargo, voyage)

      conn = post(conn, Routes.handling_report_path(conn, :create), handling_report: attrs)

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.handling_report_path(conn, :show, id))

      tracking_id = cargo.tracking_id
      voyage_number = voyage.voyage_number

      assert %{
               "id" => ^id,
               "completed_at" => "2021-10-20T03:47:00Z",
               "event_type" => "LOAD",
               "location" => "USNYC",
               "tracking_id" => ^tracking_id,
               "voyage_number" => ^voyage_number
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.handling_report_path(conn, :create), handling_report: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  defp create_handling_report(_) do
    handling_report = handling_report_fixture()
    %{handling_report: handling_report}
  end

  defp create_attrs(cargo, voyage) do
    %{
      completed_at: ~U[2021-10-20 03:47:00Z],
      event_type: "LOAD",
      location: "USNYC",
      tracking_id: cargo.tracking_id,
      voyage_number: voyage.voyage_number
    }
  end
end

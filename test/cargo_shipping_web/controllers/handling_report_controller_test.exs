defmodule CargoShippingWeb.HandlingReportControllerTest do
  use CargoShippingWeb.ConnCase

  import CargoShipping.ReportsFixtures

  alias CargoShipping.Reports.HandlingReport

  @create_attrs %{
    completed_at: ~U[2021-10-20 03:47:00Z],
    event_type: "some event_type",
    location: "some location",
    tracking_id: "some tracking_id",
    voyage_number: "some voyage_number"
  }
  @update_attrs %{
    completed_at: ~U[2021-10-21 03:47:00Z],
    event_type: "some updated event_type",
    location: "some updated location",
    tracking_id: "some updated tracking_id",
    voyage_number: "some updated voyage_number"
  }
  @invalid_attrs %{completed_at: nil, event_type: nil, location: nil, tracking_id: nil, voyage_number: nil}

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
      conn = post(conn, Routes.handling_report_path(conn, :create), handling_report: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.handling_report_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "completed_at" => "2021-10-20T03:47:00Z",
               "event_type" => "some event_type",
               "location" => "some location",
               "tracking_id" => "some tracking_id",
               "voyage_number" => "some voyage_number"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.handling_report_path(conn, :create), handling_report: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update handling_report" do
    setup [:create_handling_report]

    test "renders handling_report when data is valid", %{conn: conn, handling_report: %HandlingReport{id: id} = handling_report} do
      conn = put(conn, Routes.handling_report_path(conn, :update, handling_report), handling_report: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.handling_report_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "completed_at" => "2021-10-21T03:47:00Z",
               "event_type" => "some updated event_type",
               "location" => "some updated location",
               "tracking_id" => "some updated tracking_id",
               "voyage_number" => "some updated voyage_number"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, handling_report: handling_report} do
      conn = put(conn, Routes.handling_report_path(conn, :update, handling_report), handling_report: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete handling_report" do
    setup [:create_handling_report]

    test "deletes chosen handling_report", %{conn: conn, handling_report: handling_report} do
      conn = delete(conn, Routes.handling_report_path(conn, :delete, handling_report))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.handling_report_path(conn, :show, handling_report))
      end
    end
  end

  defp create_handling_report(_) do
    handling_report = handling_report_fixture()
    %{handling_report: handling_report}
  end
end

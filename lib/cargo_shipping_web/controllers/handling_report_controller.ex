defmodule CargoShippingWeb.HandlingReportController do
  use CargoShippingWeb, :controller

  alias CargoShipping.{HandlingReportService, Reports}

  action_fallback CargoShippingWeb.FallbackController

  def index(conn, _params) do
    handling_reports = Reports.list_handling_reports()
    render(conn, "index.json", handling_reports: handling_reports)
  end

  def create(conn, %{"handling_report" => handling_report_params}) do
    with {:ok, handling_report} <-
           HandlingReportService.submit_report(handling_report_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.handling_report_path(conn, :show, handling_report))
      |> render("show.json", handling_report: handling_report)
    end
  end

  def show(conn, %{"id" => id}) do
    handling_report = Reports.get_handling_report!(id)
    render(conn, "show.json", handling_report: handling_report)
  end
end

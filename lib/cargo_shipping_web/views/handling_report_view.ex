defmodule CargoShippingWeb.HandlingReportView do
  use CargoShippingWeb, :view
  alias CargoShippingWeb.HandlingReportView

  def render("index.json", %{handling_reports: handling_reports}) do
    %{data: render_many(handling_reports, HandlingReportView, "handling_report.json")}
  end

  def render("show.json", %{handling_report: handling_report}) do
    %{data: render_one(handling_report, HandlingReportView, "handling_report.json")}
  end

  def render("handling_report.json", %{handling_report: handling_report}) do
    %{
      id: handling_report.id,
      event_type: handling_report.event_type,
      tracking_id: handling_report.tracking_id,
      voyage_number: handling_report.voyage_number,
      location: handling_report.location,
      completed_at: handling_report.completed_at,
      received_at: handling_report.received_at
    }
  end
end

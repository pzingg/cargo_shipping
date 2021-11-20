defmodule CargoShipping.ReportsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CargoShipping.HandlingReportService` service.
  """

  @doc """
  Generate a handling_report.
  """
  def handling_report_fixture(attrs \\ %{}) do
    cargo = CargoShipping.CargoBookingsFixtures.cargo_fixture()

    {:ok, handling_report} =
      attrs
      |> Enum.into(%{
        tracking_id: cargo.tracking_id,
        version: cargo.version,
        event_type: "RECEIVE",
        location: cargo.route_specification.origin,
        completed_at: ~U[2021-10-20 03:47:00Z]
      })
      |> CargoShipping.HandlingReportService.submit_report()

    Process.sleep(100)
    handling_report
  end
end

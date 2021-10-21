defmodule CargoShipping.ReportsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CargoShipping.Reports` context.
  """

  @doc """
  Generate a handling_report.
  """
  def handling_report_fixture(attrs \\ %{}) do
    {:ok, handling_report} =
      attrs
      |> Enum.into(%{
        completed_at: ~U[2021-10-20 03:47:00Z],
        event_type: "some event_type",
        location: "some location",
        tracking_id: "some tracking_id",
        voyage_number: "some voyage_number"
      })
      |> CargoShipping.Reports.create_handling_report()

    handling_report
  end
end

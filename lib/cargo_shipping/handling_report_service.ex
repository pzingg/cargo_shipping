defmodule CargoShipping.HandlingReportService do
  @moduledoc """
  In case of a valid registration attempt, this service sends an asynchronous message
  with the information to the handling event registration system for proper registration.
  """
  require Logger

  alias CargoShipping.Reports.HandlingReport
  alias CargoShipping.Infra.Repo

  @doc """
  Creates a handling_report, generating an application event.

  ## Examples

      iex> submit_report(%{field: value})
      {:ok, %HandlingReport_{}}

      iex> submit_report(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def submit_report(attrs \\ %{}) do
    result = HandlingReport.changeset(attrs) |> Repo.insert()
    register_handling_report_attempt(result, attrs)
    result
  end

  defp register_handling_report_attempt({:ok, handling_report}, _params) do
    publish_event(:handling_report_received, handling_report)
  end

  defp register_handling_report_attempt({:error, changeset}, params) do
    publish_event(:handling_report_rejected, Map.put(params, :errors, changeset.errors))
  end

  defp publish_event(topic, payload) do
    CargoShipping.ApplicationEvents.Producer.publish_event(
      topic,
      "HandlingReportService",
      payload
    )
  end
end

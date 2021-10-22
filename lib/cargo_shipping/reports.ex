defmodule CargoShipping.Reports do
  @moduledoc """
  The Reports context.
  """
  import Ecto.Query, warn: false

  alias CargoShipping.{HandlingReportService, Repo}
  alias CargoShipping.Reports.HandlingReport

  @doc """
  Returns the list of handling_reports.

  ## Examples

      iex> list_handling_reports()
      [%HandlingReport{}, ...]

  """
  def list_handling_reports do
    Repo.all(HandlingReport)
  end

  @doc """
  Gets a single handling_report.

  Raises `Ecto.NoResultsError` if the Handling report does not exist.

  ## Examples

      iex> get_handling_report!(123)
      %HandlingReport{}

      iex> get_handling_report!(456)
      ** (Ecto.NoResultsError)

  """
  def get_handling_report!(id), do: Repo.get!(HandlingReport, id)

  @doc """
  Creates a handling_report.

  ## Examples

      iex> create_handling_report(%{field: value})
      {:ok, %HandlingReport{}}

      iex> create_handling_report(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_handling_report(attrs \\ %{}) do
    changeset =
      %HandlingReport{}
      |> HandlingReport.changeset(attrs)

    result = Repo.insert(changeset)
    HandlingReportService.register_handling_report_attempt(result, attrs)
    result
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking handling_report changes.

  ## Examples

      iex> change_handling_report(handling_report)
      %Ecto.Changeset{data: %HandlingReport{}}

  """
  def change_handling_report(%HandlingReport{} = handling_report, attrs \\ %{}) do
    HandlingReport.changeset(handling_report, attrs)
  end
end

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
    query =
      from hr in HandlingReport,
        order_by: hr.received_at

    Repo.all(query)
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
    result = change_handling_report(attrs) |> Repo.insert()
    HandlingReportService.register_handling_report_attempt(result, attrs)
    result
  end

  @doc """
  Deletes a handling report.

  ## Examples

      iex> delete_handling_report(handling_report)
      {:ok, %Cargo{}}

      iex> delete_handling_report(handling_report)
      {:error, %Ecto.Changeset{}}

  """
  def delete_handling_report(%HandlingReport{} = handling_report) do
    Repo.delete(handling_report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for creating handling reports.

  ## Examples

      iex> change_handling_report(attrs)
      %Ecto.Changeset{data: %HandlingReport{}}
  """
  def change_handling_report(attrs \\ %{}) do
    %HandlingReport{}
    |> HandlingReport.changeset(attrs)
  end
end

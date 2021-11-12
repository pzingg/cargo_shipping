defmodule CargoShipping.Reports do
  @moduledoc """
  The Reports context.
  """
  import Ecto.Query, warn: false

  alias CargoShipping.HandlingReportService
  alias CargoShipping.Infra.Repo
  alias CargoShipping.Reports.HandlingReport
  alias CargoShippingSchemas.HandlingReport, as: HandlingReport_

  @doc """
  Returns the list of handling_reports.

  ## Examples

      iex> list_handling_reports()
      [%HandlingReport_{}, ...]

  """
  def list_handling_reports do
    query =
      from hr in HandlingReport_,
        order_by: hr.received_at

    Repo.all(query)
  end

  @doc """
  Gets a single handling_report.

  Raises `Ecto.NoResultsError` if the Handling report does not exist.

  ## Examples

      iex> get_handling_report!(123)
      %HandlingReport_{}

      iex> get_handling_report!(456)
      ** (Ecto.NoResultsError)

  """
  def get_handling_report!(id), do: Repo.get!(HandlingReport_, id)

  @doc """
  Creates a handling_report.

  ## Examples

      iex> create_handling_report(%{field: value})
      {:ok, %HandlingReport_{}}

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
  def delete_handling_report(%HandlingReport_{} = handling_report) do
    Repo.delete(handling_report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for creating handling reports.

  ## Examples

      iex> change_handling_report(attrs)
      %Ecto.Changeset{data: %HandlingReport_{}}
  """
  def change_handling_report(attrs \\ %{}) do
    %HandlingReport_{}
    |> HandlingReport.changeset(attrs)
  end
end

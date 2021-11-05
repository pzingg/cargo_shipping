defmodule CargoShipping.VoyagePlans do
  @moduledoc """
  The VoyagePlans context.
  """

  import Ecto.Query, warn: false

  alias CargoShipping.{Repo, VoyageService}
  alias CargoShipping.VoyagePlans.{CarrierMovement, Voyage}

  ## Voyage module

  @doc """
  Returns the list of voyages.

  ## Examples

      iex> list_voyages()
      [%Voyage{}, ...]

  """
  def list_voyages do
    query =
      from v in Voyage,
        order_by: v.voyage_number

    Repo.all(query)
  end

  @doc """
  Gets a single voyage.

  Raises `Ecto.NoResultsError` if the Voyage does not exist.

  ## Examples

      iex> get_voyage!(123)
      %Voyage{}

      iex> get_voyage!(456)
      ** (Ecto.NoResultsError)

  """
  def get_voyage!(id), do: Repo.get!(Voyage, id)

  def get_voyage_number_for_id(nil), do: nil

  def get_voyage_number_for_id(id) do
    get_voyage!(id).voyage_number
  end

  def get_voyage_by_number(nil), do: nil

  def get_voyage_by_number(voyage_number) do
    query =
      from v in Voyage,
        where: [voyage_number: ^voyage_number]

    Repo.one(query)
  end

  def get_voyage_by_number!(voyage_number) do
    query =
      from v in Voyage,
        where: [voyage_number: ^voyage_number]

    Repo.one!(query)
  end

  @doc """
  Creates a voyage.

  ## Examples

      iex> create_voyage(%{field: value})
      {:ok, %Voyage{}}

      iex> create_voyage(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_voyage(attrs \\ %{}) do
    result =
      %Voyage{}
      |> Voyage.changeset(attrs)
      |> Repo.insert()

    VoyageService.update_cache()

    result
  end

  @doc """
  Updates a voyage.

  ## Examples

      iex> update_voyage(voyage, %{field: new_value})
      {:ok, %Voyage{}}

      iex> update_voyage(voyage, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_voyage(%Voyage{} = voyage, attrs) do
    result =
      voyage
      |> Voyage.changeset(attrs)
      |> Repo.update()

    VoyageService.update_cache()

    result
  end

  @doc """
  Deletes a voyage.

  ## Examples

      iex> delete_voyage(voyage)
      {:ok, %Voyage{}}

      iex> delete_voyage(voyage)
      {:error, %Ecto.Changeset{}}

  """
  def delete_voyage(%Voyage{} = voyage) do
    result = Repo.delete(voyage)

    VoyageService.update_cache()

    result
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking voyage changes.

  ## Examples

      iex> change_voyage(voyage)
      %Ecto.Changeset{data: %Voyage{}}

  """
  def change_voyage(%Voyage{} = voyage, attrs \\ %{}) do
    Voyage.changeset(voyage, attrs)
  end
end

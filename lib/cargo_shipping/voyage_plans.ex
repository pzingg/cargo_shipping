defmodule CargoShipping.VoyagePlans do
  @moduledoc """
  The VoyagePlans context.
  """

  import Ecto.Query, warn: false

  alias CargoShipping.Infra.Repo
  alias CargoShipping.VoyageService
  alias CargoShipping.VoyagePlans.{Voyage, CarrierMovement}
  alias CargoShippingSchemas.Voyage, as: Voyage_
  alias CargoShippingSchemas.CarrierMovement, as: CarrierMovement_

  ## Voyage module

  @doc """
  Returns the list of voyages.

  ## Examples

      iex> list_voyages()
      [%Voyage_{}, ...]

  """
  def list_voyages do
    query =
      from v in Voyage_,
        order_by: v.voyage_number

    Repo.all(query)
  end

  @doc """
  Gets a single voyage.

  Raises `Ecto.NoResultsError` if the Voyage does not exist.

  ## Examples

      iex> get_voyage!(123)
      %Voyage_{}

      iex> get_voyage!(456)
      ** (Ecto.NoResultsError)

  """
  def get_voyage!(id), do: Repo.get!(Voyage_, id)

  def get_voyage_number_for_id(nil), do: nil

  def get_voyage_number_for_id(id) do
    get_voyage!(id).voyage_number
  end

  def get_voyage_by_number(nil), do: nil

  def get_voyage_by_number(voyage_number) do
    query =
      from v in Voyage_,
        where: [voyage_number: ^voyage_number]

    Repo.one(query)
  end

  def get_voyage_by_number!(voyage_number) do
    query =
      from v in Voyage_,
        where: [voyage_number: ^voyage_number]

    Repo.one!(query)
  end

  @doc """
  Creates a voyage.

  ## Examples

      iex> create_voyage(%{field: value})
      {:ok, %Voyage_{}}

      iex> create_voyage(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_voyage(attrs \\ %{}) do
    result =
      %Voyage_{}
      |> Voyage.changeset(attrs)
      |> Repo.insert()

    VoyageService.update_cache()

    result
  end

  @doc """
  Updates a voyage.

  ## Examples

      iex> update_voyage(voyage, %{field: new_value})
      {:ok, %Voyage_{}}

      iex> update_voyage(voyage, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_voyage(%Voyage_{} = voyage, attrs) do
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
      {:ok, %Voyage_{}}

      iex> delete_voyage(voyage)
      {:error, %Ecto.Changeset{}}

  """
  def delete_voyage(%Voyage_{} = voyage) do
    result = Repo.delete(voyage)

    VoyageService.update_cache()

    result
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking voyage changes.

  ## Examples

      iex> change_voyage(voyage)
      %Ecto.Changeset{data: %Voyage_{}}

  """
  def change_voyage(%Voyage_{} = voyage, attrs \\ %{}) do
    Voyage.changeset(voyage, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for building carrier movements in voyages.

  ## Examples

      iex> change_carrier_movement(movement)
      %Ecto.Changeset{data: %CarrierMovement_{}}

  """
  def change_carrier_movement(%CarrierMovement_{} = movement, attrs \\ %{}) do
    CarrierMovement.changeset(movement, attrs)
  end
end

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
    Repo.all(Voyage)
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

  def get_voyage_number_for_id!(nil), do: nil

  def get_voyage_number_for_id!(id) do
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

  ## Schedule module

  @doc """
  Returns the list of carrier_movements.

  ## Examples

      iex> list_carrier_movements()
      [%CarrierMovement{}, ...]

  """
  def list_carrier_movements do
    Repo.all(CarrierMovement)
  end

  @doc """
  Gets a single carrier_movement.

  Raises `Ecto.NoResultsError` if the Carrier movement does not exist.

  ## Examples

      iex> get_carrier_movement!(123)
      %CarrierMovement{}

      iex> get_carrier_movement!(456)
      ** (Ecto.NoResultsError)

  """
  def get_carrier_movement!(id), do: Repo.get!(CarrierMovement, id)

  @doc """
  Creates a carrier_movement.

  ## Examples

      iex> create_carrier_movement(%{field: value})
      {:ok, %CarrierMovement{}}

      iex> create_carrier_movement(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_carrier_movement(attrs \\ %{}) do
    %CarrierMovement{}
    |> CarrierMovement.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a carrier_movement.

  ## Examples

      iex> update_carrier_movement(carrier_movement, %{field: new_value})
      {:ok, %CarrierMovement{}}

      iex> update_carrier_movement(carrier_movement, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_carrier_movement(%CarrierMovement{} = carrier_movement, attrs) do
    carrier_movement
    |> CarrierMovement.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a carrier_movement.

  ## Examples

      iex> delete_carrier_movement(carrier_movement)
      {:ok, %CarrierMovement{}}

      iex> delete_carrier_movement(carrier_movement)
      {:error, %Ecto.Changeset{}}

  """
  def delete_carrier_movement(%CarrierMovement{} = carrier_movement) do
    Repo.delete(carrier_movement)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking carrier_movement changes.

  ## Examples

      iex> change_carrier_movement(carrier_movement)
      %Ecto.Changeset{data: %CarrierMovement{}}

  """
  def change_carrier_movement(%CarrierMovement{} = carrier_movement, attrs \\ %{}) do
    CarrierMovement.changeset(carrier_movement, attrs)
  end
end

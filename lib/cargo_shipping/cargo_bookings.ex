defmodule CargoShipping.CargoBookings do
  @moduledoc """
  The CargoBookings context.
  """

  import Ecto.Query, warn: false

  alias CargoShipping.Repo
  alias CargoShipping.CargoBookings.{Cargo, Delivery, HandlingEvent}

  ## Cargo module

  @doc """
  Returns the list of cargoes.

  ## Examples

      iex> list_cargoes()
      [%Cargo{}, ...]

  """
  def list_cargoes do
    Repo.all(Cargo)
  end

  @doc """
  Gets a single cargo.

  Raises `Ecto.NoResultsError` if the Cargo does not exist.

  ## Examples

      iex> get_cargo!(123)
      %Cargo{}

      iex> get_cargo!(456)
      ** (Ecto.NoResultsError)

  """
  def get_cargo!(id), do: Repo.get!(Cargo, id)

  def get_cargo_by_tracking_id!(tracking_id) when is_binary(tracking_id) do
    query =
      from c in Cargo,
        where: c.tracking_id == ^tracking_id

    case query |> Repo.one() do
      nil ->
        raise Ecto.NoResultsError

      cargo ->
        cargo
    end
  end

  @doc """
  Creates a cargo.

  ## Examples

      iex> create_cargo(%{field: value})
      {:ok, %Cargo{}}

      iex> create_cargo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_cargo(attrs \\ %{}) do
    %Cargo{}
    |> Cargo.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cargo.

  ## Examples

      iex> update_cargo(cargo, %{field: new_value})
      {:ok, %Cargo{}}

      iex> update_cargo(cargo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_cargo(%Cargo{} = cargo, attrs) do
    cargo
    |> Cargo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cargo.

  ## Examples

      iex> delete_cargo(cargo)
      {:ok, %Cargo{}}

      iex> delete_cargo(cargo)
      {:error, %Ecto.Changeset{}}

  """
  def delete_cargo(%Cargo{} = cargo) do
    Repo.delete(cargo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cargo changes.

  ## Examples

      iex> change_cargo(cargo)
      %Ecto.Changeset{data: %Cargo{}}

  """
  def change_cargo(%Cargo{} = cargo, attrs \\ %{}) do
    Cargo.changeset(cargo, attrs)
  end

  ## HandlingEvent module

  @doc """
  Returns the list of handling_events.

  ## Examples

      iex> list_handling_events()
      [%HandlingEvent{}, ...]

  """
  def list_handling_events do
    Repo.all(HandlingEvent)
  end

  def lookup_handling_history(tracking_id) when is_binary(tracking_id) do
    query =
      from he in HandlingEvent,
        join: c in Cargo,
        on: c.id == he.cargo_id,
        where: c.tracking_id == ^tracking_id,
        order_by: [desc: he.completed_at]

    query
    |> Repo.all()
  end

  @doc """
  Updates all aspects of the `Cargo` aggregate status
  based on the current route specification, itinerary and handling of the cargo.

  When either of those three changes, i.e. when a new route is specified for the cargo,
  the cargo is assigned to a route or when the cargo is handled, the status must be
  re-calculated.

  `RouteSpecification` and `Itinerary` are both inside the `Cargo`
  aggregate, so changes to them cause the status to be updated synchronously,
  but changes to the delivery history (when a cargo is handled) cause the status update
  to happen asynchronously since `HandlingEvent` is in a different aggregate.
  """
  def derive_delivery_progress(%Cargo{} = cargo, handling_history) do
    # TODO filter events on cargo (must be same as this cargo)

    # `Delivery` is a value object, so we can simply discard the old one
    # and replace it with a new
    delivery = Delivery.derived_from(cargo.route_specification, cargo.itinerary, handling_history)
    {:ok, updated_cargo} = update_cargo(cargo, %{delivery: delivery})
    {:ok, updated_cargo}
  end

  def assign_cargo_to_route(cargo, itinerary) when is_map(itinerary) do
    # Handling consistency within the Cargo aggregate synchronously
    maybe_delivery = Map.get(cargo, :delivery, Map.get(cargo, "delivery"))

    delivery =
      maybe_delivery
      |> Delivery.update_on_routing(cargo.route_specification, itinerary)

    cargo
    |> Map.put(:itinerary, itinerary)
    |> Map.put(:delivery, delivery)
  end

  @doc """
  Gets a single handling_event.

  Raises `Ecto.NoResultsError` if the Handling event does not exist.

  ## Examples

      iex> get_handling_event!(123)
      %HandlingEvent{}

      iex> get_handling_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_handling_event!(id), do: Repo.get!(HandlingEvent, id)

  @doc """
  Creates a handling_event.

  ## Examples

      iex> create_handling_event(%{field: value})
      {:ok, %HandlingEvent{}}

      iex> create_handling_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_handling_event(attrs \\ %{}) do
    %HandlingEvent{}
    |> HandlingEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a handling_event.

  ## Examples

      iex> update_handling_event(handling_event, %{field: new_value})
      {:ok, %HandlingEvent{}}

      iex> update_handling_event(handling_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_handling_event(%HandlingEvent{} = handling_event, attrs) do
    handling_event
    |> HandlingEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a handling_event.

  ## Examples

      iex> delete_handling_event(handling_event)
      {:ok, %HandlingEvent{}}

      iex> delete_handling_event(handling_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_handling_event(%HandlingEvent{} = handling_event) do
    Repo.delete(handling_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking handling_event changes.

  ## Examples

      iex> change_handling_event(handling_event)
      %Ecto.Changeset{data: %HandlingEvent{}}

  """
  def change_handling_event(%HandlingEvent{} = handling_event, attrs \\ %{}) do
    HandlingEvent.changeset(handling_event, attrs)
  end
end
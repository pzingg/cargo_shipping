defmodule CargoShipping.CargoBookings do
  @moduledoc """
  The CargoBookings context.

  Methods in this context update aspects of the `Cargo` aggregate status
  based on the current route specification, itinerary and handling of the cargo.

  The system may handle commands that change any of these value objects:

  1. a new route is specified (origin, destination, arrival deadline) for the cargo
  2. the cargo is assigned to a different itinerary
  3. the cargo is handled

  When these events are received, the status must be re-calculated.

  `RouteSpecification` and `Itinerary` are both inside the `Cargo`
  aggregate, so changes to them cause the status to be updated synchronously,
  but changes to the delivery history (when a cargo is handled) cause the
  status update to happen asynchronously since `HandlingEvent` is in a
  different aggregate.
  """
  import Ecto.Query, warn: false

  require Logger

  alias CargoShipping.Infra.Repo
  alias CargoShippingSchemas.Cargo, as: Cargo_
  alias CargoShippingSchemas.HandlingEvent, as: HandlingEvent_

  alias CargoShipping.CargoBookings.{
    Accessors,
    Cargo,
    Delivery,
    Itinerary
  }

  alias CargoShipping.CargoBookings.Cargo.EditDestination

  ## Cargo module

  @doc """
  Returns the list of cargos.

  ## Examples

      iex> list_cargos()
      [%Cargo_{}, ...]

  """
  def list_cargos do
    query =
      from c in Cargo_,
        order_by: c.tracking_id

    Repo.all(query)
  end

  @doc """
  Gets a single cargo.

  Raises `Ecto.NoResultsError` if the Cargo does not exist.

  ## Examples

      iex> get_cargo!(123)
      %Cargo_{}

      iex> get_cargo!(456)
      ** (Ecto.NoResultsError)

  """
  def get_cargo!(id, opts \\ []) do
    if opts[:with_events] do
      query =
        from c in Cargo_,
          where: c.id == ^id,
          preload: [
            handling_events:
              ^from(
                he in HandlingEvent_,
                order_by: he.version
              )
          ]

      Repo.one!(query)
    else
      Repo.get!(Cargo_, id)
    end
  end

  def get_cargo_by_tracking_id!(tracking_id, opts \\ []) when is_binary(tracking_id) do
    query =
      if opts[:with_events] do
        from c in Cargo_,
          where: c.tracking_id == ^tracking_id,
          preload: [
            handling_events:
              ^from(
                he in HandlingEvent_,
                order_by: he.version
              )
          ]
      else
        from c in Cargo_,
          where: c.tracking_id == ^tracking_id
      end

    Repo.one!(query)
  end

  def cargo_tracking_id_exists?(nil), do: false

  def cargo_tracking_id_exists?(tracking_id) when is_binary(tracking_id) do
    query =
      from c in Cargo_,
        where: c.tracking_id == ^tracking_id

    Repo.exists?(query)
  end

  def suggest_tracking_ids(prefix) do
    if String.length(prefix) < 3 do
      []
    else
      prefix_pattern = "#{prefix}%"

      query =
        from c in Cargo_,
          where: like(c.tracking_id, ^prefix_pattern),
          select: c.tracking_id,
          order_by: c.tracking_id

      query
      |> Repo.all()
    end
  end

  @doc """
  Updates a cargo.

  ## Examples

      iex> update_cargo(cargo, %{field: new_value})
      {:ok, %Cargo_{}}

      iex> update_cargo(cargo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_cargo(%Cargo_{} = cargo, attrs) do
    changeset = Cargo.version_changeset(cargo, attrs)

    # A very bad workaround, using two updates in a single transaction,
    #  * the first one for the bigserial `:version` field, and
    #  * a second one for the changeset fields.
    #
    # The bigserial `:version` field should update correctly (it's supposed
    # to have a DEFAULT that updates it with auto-incrementing values),
    # but I cannot figure out how to have a changeset say "DEFAULT".
    multi_result =
      Ecto.Multi.new()
      |> Ecto.Multi.update_all(:cargo_version, cargos_version_query(cargo.id), [])
      |> Ecto.Multi.update(:cargo, changeset)
      |> Repo.transaction()

    case multi_result do
      {:ok, %{cargo: cargo}} ->
        {:ok, cargo}

      _error ->
        {:error, changeset}
    end
  end

  # Use Ecto.Query `fragment` to manually update the :version field.
  defp cargos_version_query(id) do
    from c in Cargo_,
      where: c.id == ^id,
      update: [set: [version: fragment("nextval('cargos_version_seq')")]]
  end

  @doc """
  Deletes a cargo.

  ## Examples

      iex> delete_cargo(cargo)
      {:ok, %Cargo_{}}

      iex> delete_cargo(cargo)
      {:error, %Ecto.Changeset{}}

  """
  def delete_cargo(%Cargo_{} = cargo) do
    Repo.delete(cargo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cargo changes.

  ## Examples

      iex> change_cargo(cargo)
      %Ecto.Changeset{data: %Cargo_{}}

  """
  def change_cargo(%Cargo_{} = cargo, attrs \\ %{}) do
    Cargo.changeset(cargo, attrs)
  end

  @doc """
  Returns a changeset that validates a change to the destination
  of a Cargo's RouteSpecification
  """
  def change_cargo_destination(%Cargo_{} = cargo, attrs \\ %{}) do
    %EditDestination{
      destination: Accessors.cargo_destination(cargo),
      arrival_deadline: Accessors.cargo_arrival_deadline(cargo)
    }
    |> EditDestination.changeset(attrs)
  end

  ## HandlingEvent module

  @doc """
  Returns the list of handling_events.

  ## Examples

      iex> list_handling_events()
      [%HandlingEvent_{}, ...]

  """
  def list_handling_events do
    query =
      from he in HandlingEvent_,
        left_join: c in Cargo_,
        on: c.id == he.cargo_id,
        select_merge: %{tracking_id: c.tracking_id},
        order_by: [desc: he.version]

    Repo.all(query)
  end

  @doc """
  Returns all the HandlingEvents related to a Cargo in descending
  order of when they were registered.
  """
  def lookup_handling_history(tracking_id) when is_binary(tracking_id) do
    query =
      from he in HandlingEvent_,
        left_join: c in Cargo_,
        on: c.id == he.cargo_id,
        select_merge: %{tracking_id: c.tracking_id},
        where: c.tracking_id == ^tracking_id,
        order_by: [desc: he.version]

    Repo.all(query)
  end

  @doc """
  Returns true if the Cargo's Itinerary is expecting the HandlingEvent.
  """
  def handling_event_expected(cargo, handling_event) do
    case Itinerary.matches_handling_event(cargo.itinerary, handling_event, ignore_completion: true) do
      {:error, message, _updated_itinerary} ->
        Logger.error(message)
        {:error, message}

      {:ok, _updated_itinerary} ->
        :ok
    end
  end

  @doc """
  Returns params that can be used to update a Cargo's itinerary and delivery.
  """
  def derive_delivery_progress(%Cargo_{} = cargo, handling_history) do
    # The `Delivery` is a value object, so we can simply discard the old one
    # and replace it with a new one.
    Delivery.params_derived_from_history(
      cargo.route_specification,
      cargo.itinerary,
      handling_history
    )
  end

  @doc """
  Gets a single handling_event.

  Raises `Ecto.NoResultsError` if the Handling event does not exist.

  ## Examples

      iex> get_handling_event!(123)
      %HandlingEvent_{}

      iex> get_handling_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_handling_event!(id) do
    query =
      from he in HandlingEvent_,
        left_join: c in Cargo_,
        on: c.id == he.cargo_id,
        select_merge: %{tracking_id: c.tracking_id},
        where: he.id == ^id

    Repo.one!(query)
  end

  @doc """
  Deletes a handling event.

  ## Examples

      iex> delete_handling_event(handling_event)
      {:ok, %Cargo_{}}

      iex> delete_handling_event(handling_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_handling_event(%HandlingEvent_{} = handling_event) do
    Repo.delete(handling_event)
  end
end

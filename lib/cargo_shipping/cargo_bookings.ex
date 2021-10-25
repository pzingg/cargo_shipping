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

  alias CargoShipping.{Repo, Utils}
  alias CargoShipping.CargoBookings.{Cargo, Delivery, HandlingEvent, Itinerary}

  ## Cargo module

  @doc """
  Returns the list of cargos.

  ## Examples

      iex> list_cargos()
      [%Cargo{}, ...]

  """
  def list_cargos do
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
  def get_cargo!(id, opts \\ []) do
    if opts[:with_events] do
      query =
        from c in Cargo,
          where: c.id == ^id,
          preload: [
            handling_events:
              ^from(
                he in HandlingEvent,
                order_by: he.completed_at
              )
          ]

      case query |> Repo.one() do
        nil ->
          raise Ecto.NoResultsError

        cargo ->
          cargo
      end
    else
      Repo.get!(Cargo, id)
    end
  end

  def get_cargo_by_tracking_id!(tracking_id, opts \\ []) when is_binary(tracking_id) do
    query =
      if opts[:with_events] do
        from c in Cargo,
          where: c.tracking_id == ^tracking_id,
          preload: [
            handling_events:
              ^from(
                he in HandlingEvent,
                order_by: he.completed_at
              )
          ]
      else
        from c in Cargo,
          where: c.tracking_id == ^tracking_id
      end

    case query |> Repo.one() do
      nil ->
        raise Ecto.NoResultsError

      cargo ->
        cargo
    end
  end

  def cargo_tracking_id_exists?(nil), do: false

  def cargo_tracking_id_exists?(tracking_id) when is_binary(tracking_id) do
    query =
      from c in Cargo,
        where: c.tracking_id == ^tracking_id

    Repo.exists?(query)
  end

  def suggest_tracking_ids(prefix) do
    if String.length(prefix) < 3 do
      []
    else
      prefix_pattern = "#{prefix}%"

      query =
        from c in Cargo,
          where: like(c.tracking_id, ^prefix_pattern),
          select: c.tracking_id,
          order_by: c.tracking_id

      query
      |> Repo.all()
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
    {itinerary, other_attrs} = Map.pop(attrs, :itinerary)

    recalculated_attrs =
      if itinerary do
        cargo_params_for_new_itinerary(other_attrs, itinerary)
      else
        attrs
      end

    Cargo.changeset(%Cargo{}, recalculated_attrs)
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
    Cargo.changeset(cargo, attrs)
    |> Repo.update()
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new RouteSpecification that
  has a different destination.  The origin and arrival_deadline are
  not changed.
  """
  def update_cargo_for_new_destination(%Cargo{} = cargo, destination) do
    new_route_specification = %{cargo.route_specification | destination: destination}

    update_cargo_for_new_route(cargo, new_route_specification)
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new RouteSpecification.
  """
  def update_cargo_for_new_route(cargo, route_specification) do
    params = new_route_params(cargo, route_specification)
    update_cargo(cargo, params)
  end

  defp new_route_params(%{itinerary: itinerary} = cargo, route_specification) do
    delivery = Delivery.params_derived_from_routing(nil, route_specification, itinerary)

    cargo
    |> Utils.from_struct()
    |> Map.merge(%{
      route_specification: route_specification,
      itinerary: Utils.from_struct(itinerary),
      delivery: delivery
    })
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new Itinerary after
  re-routing.
  """
  def update_cargo_for_new_itinerary(cargo, itinerary) do
    params = cargo_params_for_new_itinerary(cargo, itinerary)
    update_cargo(cargo, params)
  end

  # Argument `cargo` can be a map (when creating cargos), or an existing Cargo struct.
  defp cargo_params_for_new_itinerary(
         %{route_specification: route_specification} = cargo,
         itinerary
       )
       when is_map(itinerary) do
    # Handling consistency within the Cargo aggregate synchronously
    maybe_delivery = Map.get(cargo, :delivery) || Map.get(cargo, "delivery")

    delivery =
      Delivery.params_derived_from_routing(maybe_delivery, route_specification, itinerary)

    cargo
    |> Utils.from_struct()
    |> Map.merge(%{
      route_specification: Utils.from_struct(route_specification),
      itinerary: itinerary,
      delivery: delivery
    })
  end

  def get_remaining_route_specification(cargo) do
    case {cargo.delivery.route_status, cargo.delivery.transport_status} do
      {:NOT_ROUTED, _} ->
        cargo.route_specifiction

      {_, :CLAIMED} ->
        nil

      {_, :IN_PORT} ->
        origin = cargo.delivery.last_known_location
        mabye_route_specification(cargo.route_specification, origin)

      {_, :ONBOARD_CARRIER} ->
        origin = cargo.delivery.next_expected_activity.location
        mabye_route_specification(cargo.route_specification, origin)

      {_, _} ->
        cargo.route_specifiction
    end
  end

  defp mabye_route_specification(route_specification, new_origin) do
    if new_origin == route_specification.destination do
      nil
    else
      %{route_specification | origin: new_origin}
    end
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

  @doc """
  Returns a changeset that validates a change to the destination
  of a Cargo's RouteSpecification
  """
  def change_cargo_destination(%Cargo{} = cargo, attrs \\ %{}) do
    %Cargo.EditDestination{destination: Cargo.destination(cargo)}
    |> Cargo.EditDestination.changeset(attrs)
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

  @doc """
  Returns all the HandlingEvents related to a Cargo in descending
  order of when they were registered.
  """
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
  Returns true if the Cargo's Itinerary is expecting the HandlingEvent.
  """
  def handling_event_expected(cargo, handling_event) do
    Itinerary.handling_event_expected(cargo.itinerary, handling_event)
  end

  @doc """
  Returns params that can be used to update a Cargo's delivery status.
  """
  def derive_delivery_progress(%Cargo{} = cargo, handling_history) do
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
      %HandlingEvent{}

      iex> get_handling_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_handling_event!(id), do: Repo.get!(HandlingEvent, id)

  @doc """
  Creates a handling_event.

  ## Examples

      iex> create_handling_event(cargo, %{field: value})
      {:ok, %HandlingEvent{}}

      iex> create_handling_event(cargo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_handling_event(cargo, attrs \\ %{}) do
    cargo_id_key =
      if Utils.atom_keys?(attrs) do
        :cargo_id
      else
        "cargo_id"
      end

    create_attrs = Map.put(attrs, cargo_id_key, cargo.id)

    %HandlingEvent{}
    |> HandlingEvent.changeset(create_attrs)
    |> Repo.insert()
  end

  def create_handling_event_from_report(attrs \\ %{}) do
    changeset = HandlingEvent.handling_report_changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, handling_event} ->
        {:ok, handling_event, attrs}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a handling event.

  ## Examples

      iex> delete_handling_event(handling_event)
      {:ok, %Cargo{}}

      iex> delete_handling_event(handling_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_handling_event(%HandlingEvent{} = handling_event) do
    Repo.delete(handling_event)
  end
end

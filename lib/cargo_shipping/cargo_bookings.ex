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

      Repo.one!(query)
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

    Repo.one!(query)
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
  def update_cargo_for_new_destination(%Cargo{} = cargo, destination, arrival_deadline \\ nil) do
    route_specification =
      cargo.route_specification
      |> Map.put(:destination, destination)
      |> Utils.from_struct()

    new_route_specification =
      if is_nil(arrival_deadline) do
        route_specification
      else
        Map.put(route_specification, :arrival_deadline, arrival_deadline)
      end

    update_cargo_for_new_route(cargo, new_route_specification)
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new RouteSpecification.
  """
  def update_cargo_for_new_route(cargo, route_specification) do
    params = new_route_params(cargo, route_specification)
    update_cargo(cargo, params)
  end

  defp new_route_params(%{delivery: delivery, itinerary: itinerary} = cargo, route_specification) do
    # Use the cargo's delivery to preserve the last_event
    params = Delivery.params_derived_from_routing(delivery, route_specification, itinerary)

    cargo
    |> Map.put(:route_specification, route_specification)
    |> Map.merge(params)
    |> Utils.from_struct()
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new Itinerary after
  re-routing.
  """
  def update_cargo_for_new_itinerary(cargo, itinerary, remaining_route_spec \\ nil) do
    params = cargo_params_for_new_itinerary(cargo, itinerary, remaining_route_spec)
    update_cargo(cargo, params)
  end

  # Argument `cargo` can be a map (when creating cargos), or an existing Cargo struct.
  defp cargo_params_for_new_itinerary(cargo, new_itinerary, patch_route_spec \\ nil)
       when is_map(new_itinerary) do
    {route_specification, itinerary} =
      patch_route_specification_and_itinerary(cargo, patch_route_spec, new_itinerary)

    # Handling consistency within the Cargo aggregate synchronously
    maybe_delivery = Map.get(cargo, :delivery) || Map.get(cargo, "delivery")

    params = Delivery.params_derived_from_routing(maybe_delivery, route_specification, itinerary)

    cargo
    |> Map.put(:route_specification, route_specification)
    |> Map.merge(params)
    |> Utils.from_struct()
  end

  def patch_route_specification_and_itinerary(cargo, nil, new_itinerary) do
    {cargo.route_specification, new_itinerary}
  end

  def patch_route_specification_and_itinerary(cargo, patch_route_spec, patch_itinerary) do
    if cargo.route_specification == patch_route_spec do
      {cargo.route_specification, patch_itinerary}
    else
      # This is probably a no-op
      new_route_spec = %{
        cargo.route_specification
        | destination: patch_route_spec.destination,
          arrival_deadline: patch_route_spec.arrival_deadline
      }

      new_itinerary = merge_itinerary(cargo.itinerary, patch_itinerary, patch_route_spec.origin)

      Logger.debug("original route spec #{inspect(cargo.route_specification)}")
      Logger.debug("patched route spec #{inspect(new_route_spec)}")
      Logger.debug("original itinerary #{inspect(cargo.itinerary)}")
      Logger.debug("patched itinerary #{inspect(new_itinerary)}")
      {new_route_spec, new_itinerary}
    end
  end

  def merge_itinerary(itinerary, patch_itinerary, origin) do
    if Enum.empty?(patch_itinerary.legs) do
      raise "patched itinerary has no legs"
    end

    itinerary_departure = Itinerary.initial_departure_location(patch_itinerary)

    if itinerary_departure != origin do
      raise "patched itinerary expected departure #{origin}, was #{itinerary_departure}"
    end

    {first_legs, next_legs} = Itinerary.split_completed_legs(itinerary, origin)
    first_arrival = Itinerary.final_arrival_location(%{legs: first_legs})

    if first_arrival != origin do
      raise "first part itinerary expected arrival #{origin}, was #{first_arrival}"
    end

    next_departure = Itinerary.initial_departure_location(%{legs: next_legs})

    if next_departure != origin do
      raise "next part itinerary expected departure #{origin}, was #{next_departure}"
    end

    Itinerary.new(first_legs ++ patch_itinerary.legs)
  end

  def get_remaining_route_specification(cargo) do
    case {cargo.delivery.routing_status, cargo.delivery.transport_status} do
      {:NOT_ROUTED, _} ->
        Logger.debug("Cargo not routed, rrs is original route specification")
        cargo.route_specification

      {_, :CLAIMED} ->
        Logger.debug("Cargo has been claimed, rrs is nil")
        nil

      {_, :IN_PORT} ->
        origin = cargo.delivery.last_known_location
        maybe_route_specification(cargo.route_specification, origin, "Cargo is in port at")

      {_, :ONBOARD_CARRIER} ->
        case cargo.delivery.next_expected_activity do
          nil ->
            Logger.error(
              "No expected activity while ONBOARD, rrs is original route specification"
            )

            cargo.route_specification

          activity ->
            maybe_route_specification(
              cargo.route_specification,
              activity.location,
              "Cargo is onboard to"
            )
        end

      {_, other} ->
        Logger.debug("Cargo transport is #{other}, rrs is original route specification")
        cargo.route_specification
    end
  end

  defp maybe_route_specification(route_specification, new_origin, status) do
    cond do
      new_origin == route_specification.origin ->
        Logger.debug("#{status} origin, rrs is original route specification")
        route_specification

      new_origin == route_specification.destination ->
        Logger.debug("#{status} final destination, rrs is nil")
        nil

      true ->
        Logger.debug("#{status} rrs set with this location as origin")
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
    %Cargo.EditDestination{
      destination: Cargo.destination(cargo),
      arrival_deadline: Cargo.arrival_deadline(cargo)
    }
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
    query =
      from he in HandlingEvent,
        left_join: c in Cargo,
        on: c.id == he.cargo_id,
        select_merge: %{tracking_id: c.tracking_id},
        order_by: [desc: he.completed_at]

    Repo.all(query)
  end

  @doc """
  Returns all the HandlingEvents related to a Cargo in descending
  order of when they were registered.
  """
  def lookup_handling_history(tracking_id) when is_binary(tracking_id) do
    query =
      from he in HandlingEvent,
        left_join: c in Cargo,
        on: c.id == he.cargo_id,
        select_merge: %{tracking_id: c.tracking_id},
        where: c.tracking_id == ^tracking_id,
        order_by: [desc: he.completed_at]

    Repo.all(query)
  end

  @doc """
  Returns true if the Cargo's Itinerary is expecting the HandlingEvent.
  """
  def handling_event_expected(cargo, handling_event) do
    case Itinerary.matches_handling_event(cargo.itinerary, handling_event) do
      {:error, message, _movement_info} ->
        Logger.error(message)
        {:error, message}

      {:ok, _updated_itinerary} ->
        :ok
    end
  end

  @doc """
  Returns params that can be used to update a Cargo's itinerary and delivery.
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
  def get_handling_event!(id) do
    query =
      from he in HandlingEvent,
        left_join: c in Cargo,
        on: c.id == he.cargo_id,
        select_merge: %{tracking_id: c.tracking_id},
        where: he.id == ^id

    Repo.one!(query)
  end

  @doc """
  Creates a handling_event.

  ## Examples

      iex> create_handling_event(cargo, %{field: value})
      {:ok, %HandlingEvent{}}

      iex> create_handling_event(cargo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_handling_event(cargo, attrs \\ %{}) do
    create_attrs = set_cargo_id(cargo, attrs)
    changeset = HandlingEvent.changeset(create_attrs)
    create_and_publish_handling_event(changeset)
  end

  def create_handling_event_from_report(attrs \\ %{}) do
    changeset = HandlingEvent.handling_report_changeset(attrs)
    create_and_publish_handling_event(changeset)
  end

  defp create_and_publish_handling_event(changeset) do
    tracking_id = Ecto.Changeset.get_field(changeset, :tracking_id)

    case Repo.insert(changeset) do
      {:ok, handling_event} ->
        # Publish an event stating that a cargo has been handled.
        payload = Map.put(handling_event, :tracking_id, tracking_id)
        publish_event(:cargo_was_handled, payload)
        {:ok, handling_event}

      {:error, changeset} ->
        # Publish an event stating that the event was rejected.
        publish_event(:cargo_handling_rejected, changeset)
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

  ## Utility functions

  def publish_event(topic, payload) do
    CargoShipping.ApplicationEvents.Producer.publish_event(topic, "CargoBookings", payload)
  end

  def set_cargo_id_from_tracking_id(attrs) do
    tracking_id = Map.get(attrs, :tracking_id) || Map.get(attrs, "tracking_id")

    if is_nil(tracking_id) do
      {:error, "can't be blank"}
    else
      case get_cargo_by_tracking_id!(tracking_id) do
        nil ->
          {:error, "is_invalid"}

        cargo ->
          {:ok, set_cargo_id(cargo, attrs)}
      end
    end
  end

  def set_cargo_id(cargo, attrs) do
    {cargo_id_key, tracking_id_key} =
      if Utils.atom_keys?(attrs) do
        {:cargo_id, :tracking_id}
      else
        {"cargo_id", "tracking_id"}
      end

    attrs
    |> Map.put(cargo_id_key, cargo.id)
    |> Map.put(tracking_id_key, cargo.tracking_id)
  end
end

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

  alias CargoShipping.Utils
  alias CargoShipping.Infra.Repo
  alias CargoShippingSchemas.Cargo, as: Cargo_
  alias CargoShippingSchemas.HandlingEvent, as: HandlingEvent_

  alias CargoShipping.CargoBookings.{
    Accessors,
    Cargo,
    Delivery,
    HandlingEvent,
    Itinerary,
    RouteSpecification
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
                order_by: he.completed_at
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
                order_by: he.completed_at
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
  Creates a cargo.

  ## Examples

      iex> create_cargo(%{field: value})
      {:ok, %Cargo_{}}

      iex> create_cargo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_cargo(raw_attrs \\ %{}) do
    # Because we need to pre-process the attributes, we must convert
    # the keys into atoms.
    attrs = Utils.atomize(raw_attrs)
    route_specification = Map.get(attrs, :route_specification)
    itinerary = Map.get(attrs, :itinerary)

    recalculated_attrs =
      if itinerary do
        derived_routing_params(attrs, route_specification, itinerary)
      else
        attrs
      end

    Cargo.changeset(%Cargo_{}, recalculated_attrs)
    |> Repo.insert()
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
    Cargo.changeset(cargo, attrs)
    |> Repo.update()
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new RouteSpecification that
  has a different destination.  The origin and arrival_deadline are
  not changed.
  """
  def update_cargo_for_new_destination(%Cargo_{} = cargo, destination, arrival_deadline \\ nil) do
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
    params = new_route_params(cargo, cargo.delivery, route_specification, cargo.itinerary)
    update_cargo(cargo, params)
  end

  defp new_route_params(cargo, delivery, route_specification, itinerary) do
    itinerary_and_delivery_params =
      Delivery.new_route_params(delivery, route_specification, itinerary)

    cargo
    |> Map.put(:route_specification, route_specification)
    |> Map.merge(itinerary_and_delivery_params)
    |> Utils.from_struct()
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new Itinerary after re-routing.
  """
  def update_cargo_for_new_itinerary(
        cargo,
        itinerary,
        patch_uncompleted_leg?
      ) do
    merged_itinerary = merge_itinerary(cargo.itinerary, itinerary, patch_uncompleted_leg?)

    route_specification =
      Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

    Itinerary.debug_itinerary(merged_itinerary, "merged_itinerary")
    Accessors.debug_route_specification(route_specification, "from merged_itinerary")

    params = new_route_params(cargo, cargo.delivery, route_specification, merged_itinerary)
    update_cargo(cargo, params)
  end

  @doc """
  Argument `cargo` can be a map with atom keys (when creating cargos), or an existing Cargo struct.
  """
  def derived_routing_params(cargo, route_specification, itinerary) do
    # Handling consistency within the Cargo aggregate synchronously

    delivery = Map.get(cargo, :delivery)
    # Just check :routing_status and :eta
    itinerary_and_delivery_params =
      Delivery.params_derived_from_routing(delivery, route_specification, itinerary)

    cargo
    |> Map.put(:route_specification, route_specification)
    |> Map.merge(itinerary_and_delivery_params)
    |> Utils.from_struct()
  end

  def merge_itinerary(old_itinerary, new_itinerary, patch_uncompleted_leg?) do
    {uncompleted_legs, active_legs} = Accessors.itinerary_split_completed_legs(old_itinerary)

    new_legs =
      if patch_uncompleted_leg? do
        # patch_uncompleted_leg? is set for misdirected LOAD
        # Here we update the first new leg with data
        # from the original uncompleted leg.
        active_leg = List.first(active_legs)
        List.update_at(new_itinerary.legs, 0, fn leg -> merge_active_leg(leg, active_leg) end)
      else
        new_itinerary.legs
      end

    Logger.debug("merge_itineary patch_uncompleted #{patch_uncompleted_leg?}")
    Itinerary.debug_itinerary(%{legs: uncompleted_legs}, "uncompleted_legs")
    Itinerary.debug_itinerary(%{legs: active_legs}, "active_legs")
    Itinerary.debug_itinerary(%{legs: new_legs}, "new_legs")
    legs = uncompleted_legs ++ new_legs

    Utils.from_struct(legs) |> Itinerary.new()
  end

  defp merge_active_leg(new_leg, active_leg) do
    load_keys =
      if !is_nil(active_leg.actual_load_location) do
        [:actual_load_location, :load_location]
      else
        []
      end

    unload_keys =
      if !is_nil(active_leg.actual_unload_location) do
        [:actual_unload_location, :unload_location]
      else
        []
      end

    ([:status, :load_time, :unload_time] ++ load_keys ++ unload_keys)
    |> Enum.reduce(new_leg, fn key, acc -> Map.put(acc, key, Map.get(active_leg, key)) end)
  end

  @doc """
  Returns a tuple
    * route specification, or nil if at destination
    * boolean, true if the route specification has a different origin from cargo
    * boolean, true true if the merged itinerary should use data from the last
      uncompleted leg when merging, or false if the new itinerary can just be appended
  """
  def get_remaining_route_specification(cargo) do
    # TODO: set :earliest_departure
    location = Accessors.cargo_last_known_location(cargo)
    event_type = Accessors.cargo_last_event_type(cargo)
    completed_legs = Accessors.itinerary_completed_legs(cargo)

    case {Accessors.cargo_routing_status(cargo), Accessors.cargo_transport_status(cargo)} do
      {:NOT_ROUTED, _} ->
        Logger.debug("Cargo not routed, rrs is original route specification")
        {cargo.route_specification, completed_legs, false, false}

      {_, :CLAIMED} ->
        Logger.debug("Cargo has been claimed, rrs is nil")
        {nil, completed_legs, false, false}

      {_, :IN_PORT} ->
        # :RECEIVE or :UNLOAD
        {route_spec, new_origin?} =
          maybe_route_specification(
            cargo.route_specification,
            location,
            "After #{event_type}, cargo is (misdirected) in port at"
          )

        {route_spec, completed_legs, new_origin?, false}

      {_, :ONBOARD_CARRIER} ->
        #  :LOAD
        {route_spec, new_origin?} =
          maybe_route_specification(
            cargo.route_specification,
            location,
            "After #{event_type}, cargo is on board (misdirected) from"
          )

        {route_spec, completed_legs, new_origin?, true}

      {_, other} ->
        Logger.debug(
          "After #{event_type}, cargo transport is #{other}, rrs is original route specification"
        )

        {cargo.route_specification, completed_legs, false, false}
    end
  end

  @doc """
  Returns tuple of a route specification and a the possible new origin for the
  remaining part of the cargo's delivery.
  """
  def maybe_route_specification(route_specification, new_origin, status) do
    cond do
      new_origin == route_specification.origin ->
        Logger.debug("#{status} origin, rrs is original route specification")
        {route_specification, false}

      new_origin == route_specification.destination ->
        Logger.debug("#{status} final destination, rrs is nil")
        {nil, false}

      true ->
        # TODO: set :earliest_departure
        Logger.debug("#{status} rrs set with this location as origin")
        {%{route_specification | origin: new_origin}, true}
    end
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
        order_by: [desc: he.completed_at]

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
        order_by: [desc: he.completed_at]

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
  Creates a handling_event.

  ## Examples

      iex> create_handling_event(cargo, %{field: value})
      {:ok, %HandlingEvent_{}}

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
      {:ok, %Cargo_{}}

      iex> delete_handling_event(handling_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_handling_event(%HandlingEvent_{} = handling_event) do
    Repo.delete(handling_event)
  end

  ## Utility functions

  def publish_event(topic, payload) do
    CargoShipping.ApplicationEvents.Producer.publish_event(topic, "CargoBookings", payload)
  end

  def set_cargo_id_from_tracking_id(attrs) do
    tracking_id = Utils.get(attrs, :tracking_id)

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

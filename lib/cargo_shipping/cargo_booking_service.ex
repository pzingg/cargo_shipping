defmodule CargoShipping.CargoBookingService do
  @moduledoc false
  require Logger

  alias CargoShipping.ApplicationEvents.Producer
  alias CargoShipping.{CargoBookings, RoutingService, Utils}
  alias CargoShipping.Infra.Repo
  alias CargoShipping.CargoBookings.{Accessors, Cargo, Delivery, Itinerary}
  alias CargoShippingSchemas.Cargo, as: Cargo_
  alias CargoShippingSchemas.RouteCandidate

  @doc """
  Create an unrouted Cargo with the givien route specification parameters.
  """
  def book_new_cargo(origin, destination, arrival_deadline, earliest_departure \\ nil) do
    case unique_tracking_id() do
      {:ok, tracking_id} ->
        attrs = %{
          tracking_id: tracking_id,
          route_specification: %{
            origin: origin,
            destination: destination,
            earliest_departure: earliest_departure,
            arrival_deadline: arrival_deadline
          },
          delivery: Delivery.not_routed()
        }

        {:ok, cargo} = create_cargo_and_publish_event(attrs)

        cargo.tracking_id

      {:error, _} ->
        nil
    end
  end

  @doc """
  Creates a cargo. `attrs` must include a route specification, and optionally
  can include an itinerary.

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
    route_specification = Map.fetch!(attrs, :route_specification)
    itinerary = Map.get(attrs, :itinerary)

    recalculated_attrs =
      if itinerary do
        derived_routing_params(attrs, route_specification, itinerary)
      else
        attrs
      end

    create_cargo_and_publish_event(recalculated_attrs)
  end

  @doc """
  Public access for testing. Argument `cargo` can be a map with atom keys
  (when creating cargos), or an existing Cargo struct.
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

  @doc """
  Returns a 2-tuple:
    * the remaining route specification for the cargo, with its
      `:patch_uncompleted_leg?` attribute set if the merged itinerary
      should use data from the last uncompleted leg when merging, or
      not set if the new itinerary can just be appended
    * a list of possible replacement itineraries for the uncompleted legs

  If there are no remaining ports for the cargo, nil is returned.
  If there are no found itineraries, nil is returned.
  """
  def request_possible_routes_for_cargo(tracking_id) when is_binary(tracking_id) do
    CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    |> request_possible_routes_for_cargo()
  end

  def request_possible_routes_for_cargo(%CargoShippingSchemas.Cargo{} = cargo) do
    remaining_route_spec = get_remaining_route_specification(cargo)

    if is_nil(remaining_route_spec) do
      # We are at our destination
      {nil, nil}
    else
      internal_itinerary =
        if remaining_route_spec.origin != cargo.route_specification.origin do
          case Itinerary.internal_itinerary_for_route_specification(
                 cargo.itinerary,
                 remaining_route_spec
               ) do
            nil ->
              nil

            itinerary ->
              %RouteCandidate{itinerary: itinerary, cost: -1}
          end
        else
          nil
        end

      other_itineraries =
        RoutingService.fetch_routes_for_specification(remaining_route_spec,
          algorithm: :libgraph,
          find: :all
        )

      patch_uncompleted_leg = Map.get(remaining_route_spec, :patch_uncompleted_leg?, false)

      itineraries =
        [internal_itinerary | other_itineraries]
        |> Enum.reject(&is_nil(&1))
        |> Enum.map(fn candidate ->
          Map.update!(
            candidate,
            :itinerary,
            &Map.put(&1, :patch_uncompleted_leg?, patch_uncompleted_leg)
          )
        end)

      {remaining_route_spec, itineraries}
    end
  end

  @doc """
  Public access for testing.

  Returns a route specification, with its
    `:patch_uncompleted_leg?` attribute set if the merged itinerary
    should use data from the last uncompleted leg when merging, or
    not set if the new itinerary can just be appended.
  Returns `nil` if cargo is already at destination.
  """
  def get_remaining_route_specification(cargo) do
    # TODO: set :earliest_departure
    location = Accessors.cargo_last_known_location(cargo)
    event_type = Accessors.cargo_last_event_type(cargo)

    case {Accessors.cargo_routing_status(cargo), Accessors.cargo_transport_status(cargo)} do
      {:NOT_ROUTED, _} ->
        Logger.debug("Cargo not routed, rrs is original route specification")
        cargo.route_specification

      {_, :CLAIMED} ->
        Logger.debug("Cargo has been claimed, rrs is nil")
        nil

      {_, :IN_PORT} ->
        # :RECEIVE or :UNLOAD
        maybe_route_specification(
          cargo.route_specification,
          location,
          "After #{event_type}, cargo is (misdirected) in port at"
        )

      {_, :ONBOARD_CARRIER} ->
        #  :LOAD
        case maybe_route_specification(
               cargo.route_specification,
               location,
               "After #{event_type}, cargo is on board (misdirected) from"
             ) do
          nil ->
            nil

          route_specification ->
            Map.put(route_specification, :patch_uncompleted_leg?, true)
        end

      {_, other} ->
        Logger.debug(
          "After #{event_type}, cargo transport is #{other}, rrs is original route specification"
        )

        cargo.route_specification
    end
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new RouteSpecification that
  has a different destination.  The origin and arrival_deadline are
  not changed.
  """
  def change_destination(%Cargo_{} = cargo, destination) when is_binary(destination) do
    route_specification =
      cargo.route_specification
      |> Map.put(:destination, destination)

    change_destination(cargo, route_specification)
  end

  def change_destination(%Cargo_{} = cargo, route_specification) do
    params = specify_new_route(cargo, Utils.from_struct(route_specification))
    CargoBookings.update_cargo(cargo, params)
  end

  @doc """
  Synchronously updates the Cargo aggregate with a new Itinerary after re-routing.
  """
  def assign_cargo_to_route(
        cargo,
        itinerary
      ) do
    patch_uncompleted_leg = Map.get(itinerary, :patch_uncompleted_leg?, false)
    merged_itinerary = merge_itinerary(cargo.itinerary, itinerary, patch_uncompleted_leg)

    new_route_specification =
      Itinerary.to_route_specification(merged_itinerary, cargo.route_specification)

    Itinerary.debug_itinerary(merged_itinerary, "merged_itinerary")
    Accessors.debug_route_specification(new_route_specification, "from merged_itinerary")

    params = specify_new_route(cargo, new_route_specification, merged_itinerary)
    CargoBookings.update_cargo(cargo, params)
  end

  @doc """
  Public access for testing.
  """
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

  ## Private functions

  defp unique_tracking_id(try \\ 5)

  defp unique_tracking_id(0), do: {:error, :generator_failed}

  defp unique_tracking_id(try) do
    tracking_id =
      Enum.reduce(1..6, "", fn i, acc ->
        val =
          if i <= 3 do
            [Enum.random(?A..?Z)]
          else
            Enum.random(1..9)
          end

        acc <> to_string(val)
      end)

    if CargoBookings.cargo_tracking_id_exists?(tracking_id) do
      unique_tracking_id(try - 1)
    else
      {:ok, tracking_id}
    end
  end

  defp create_cargo_and_publish_event(params) do
    result =
      Cargo.changeset(%Cargo_{}, params)
      |> Repo.insert()

    case result do
      {:ok, cargo} ->
        publish_event(:cargo_booked, cargo)

      {:error, changeset} ->
        publish_event(:cargo_booking_failed, changeset)
    end

    result
  end

  # Returns a route specification if the origin specified is not the destination.
  defp maybe_route_specification(route_specification, new_origin, status) do
    cond do
      new_origin == route_specification.origin ->
        Logger.debug("#{status} origin, rrs is original route specification")
        route_specification

      new_origin != route_specification.destination ->
        # TODO: set :earliest_departure
        Logger.debug("#{status} rrs set with this location as origin")
        %{route_specification | origin: new_origin}

      true ->
        Logger.debug("#{status} final destination, rrs is nil")
        nil
    end
  end

  defp specify_new_route(cargo, route_specification, itinerary \\ nil) do
    itinerary_and_delivery_params =
      Delivery.new_route_params(cargo.delivery, route_specification, itinerary || cargo.itinerary)

    cargo
    |> Map.put(:route_specification, route_specification)
    |> Map.merge(itinerary_and_delivery_params)
    |> Utils.from_struct()
  end

  defp merge_active_leg(new_leg, active_leg) do
    load_keys =
      if is_nil(active_leg.actual_load_location) do
        []
      else
        [:actual_load_location, :load_location]
      end

    unload_keys =
      if is_nil(active_leg.actual_unload_location) do
        []
      else
        [:actual_unload_location, :unload_location]
      end

    ([:status, :load_time, :unload_time] ++ load_keys ++ unload_keys)
    |> Enum.reduce(new_leg, fn key, acc -> Map.put(acc, key, Map.get(active_leg, key)) end)
  end

  defp publish_event(topic, payload) do
    Producer.publish_event(
      topic,
      "CargoBookingService",
      payload
    )
  end
end

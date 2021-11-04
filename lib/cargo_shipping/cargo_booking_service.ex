defmodule CargoShipping.CargoBookingService do
  @moduledoc false
  require Logger

  alias CargoShipping.{CargoBookings, RoutingService}
  alias CargoShipping.CargoBookings.{Cargo, Delivery, Itinerary}

  @doc false
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

        {:ok, cargo} = CargoBookings.create_cargo(attrs)

        Logger.info("Booked new cargo with tracking id #{cargo.tracking_id}")

        cargo.tracking_id

      {:error, _} ->
        nil
    end
  end

  def unique_tracking_id(try \\ 5)

  def unique_tracking_id(0), do: {:error, :generator_failed}

  def unique_tracking_id(try) do
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

    Logger.debug("new tracking_id #{tracking_id}")

    if CargoBookings.cargo_tracking_id_exists?(tracking_id) do
      unique_tracking_id(try - 1)
    else
      {:ok, tracking_id}
    end
  end

  @doc """
  Returns a 4-tuple
    * the remaining route specification for the cargo
    * the completed legs of the cargo's current itinerary
    * a list of possible replacement itineraries for the uncompleted legs
    * boolean, true if the merged itinerary should use data from the
      last uncompleted leg when merging, or false if the new itinerary can just be
      appended

  If there are no remaining ports for the cargo, nil is returned.
  If there are no found itineraries, nil is returned.
  """
  def possible_routes_for_cargo(tracking_id) when is_binary(tracking_id) do
    CargoBookings.get_cargo_by_tracking_id!(tracking_id)
    |> possible_routes_for_cargo()
  end

  def possible_routes_for_cargo(%Cargo{} = cargo) do
    {remaining_route_spec, completed_legs, has_new_origin?, patch_uncompleted_leg?} =
      CargoBookings.get_remaining_route_specification(cargo)

    if is_nil(remaining_route_spec) do
      # We are at our destination
      {nil, nil}
    else
      internal_itinerary =
        if has_new_origin? do
          case Itinerary.internal_itinerary_for_route_specification(
                 cargo.itinerary,
                 remaining_route_spec
               ) do
            nil ->
              nil

            itinerary ->
              %{itinerary: itinerary, cost: -1}
          end
        else
          nil
        end

      other_itineraries =
        ranked_itineraries_for_route_specification(remaining_route_spec,
          algorithm: :libgraph,
          find: :all
        )

      itineraries =
        [internal_itinerary | other_itineraries]
        |> Enum.reject(&is_nil(&1))

      {remaining_route_spec, completed_legs, itineraries, patch_uncompleted_leg?}
    end
  end

  @doc """
  The RouteSpecification is picked apart and adapted to the external API.
  """
  def ranked_itineraries_for_route_specification(route_specification, opts \\ []) do
    RoutingService.find_itineraries(
      route_specification.origin,
      route_specification.destination,
      opts
      |> Keyword.put(:earliest_departure, route_specification.earliest_departure)
      |> Keyword.put(:arrival_deadline, route_specification.arrival_deadline)
    )
    |> Enum.filter(fn %{itinerary: itinerary} ->
      filter = Itinerary.satisfies?(itinerary, route_specification)

      if !filter do
        Logger.error("itinerary fails to satisfy route specification")
        Itinerary.debug_itinerary(itinerary)
      end

      filter
    end)
  end
end

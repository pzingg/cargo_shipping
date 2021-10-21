defmodule CargoShipping.CargoBookings do
  @moduledoc """
  The CargoBookings context.
  """
  import Ecto.Query, warn: false

  require Logger

  alias CargoShipping.Repo
  alias CargoShipping.CargoBookings.{Cargo, Itinerary, Delivery, HandlingEvent}
  alias CargoShipping.RoutingService

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
  def get_cargo!(id), do: Repo.get!(Cargo, id)

  def get_cargo_and_events!(id) do
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
  end

  def get_cargo_by_tracking_id!(tracking_id) when is_binary(tracking_id) do
    query =
      from c in Cargo,
        where: c.tracking_id == ^tracking_id,
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
  end

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

  def update_cargo_destination(%Cargo{} = cargo, destination) do
    route_specification = %{
      origin: cargo.route_specification.origin,
      destination: destination,
      arrival_deadline: cargo.route_specification.arrival_deadline
    }

    attrs = specify_new_route(cargo, route_specification)
    Logger.error("update_cargo_destination #{inspect(attrs)}")

    update_cargo(cargo, attrs)
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

  def possible_routes_for_cargo(cargo) do
    itineraries = routes_for_specification(cargo.route_specification)
    Logger.info("possible_routes #{inspect(itineraries)}")
    itineraries
  end

  @doc """
  The RouteSpecification is picked apart and adapted to the external API.
  """
  def routes_for_specification(route_specification) do
    limitations = [deadline: route_specification.arrival_deadline]

    RoutingService.find_itineraries(
      route_specification.origin,
      route_specification.destination,
      limitations
    )
    |> Enum.filter(fn itinerary ->
      Itinerary.satisfies?(itinerary, route_specification)
    end)
  end

  def handling_event_expected(cargo, handling_event) do
    Itinerary.handling_event_expected(cargo.itinerary, handling_event)
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
    # and replace it with a new one.
    Delivery.derived_from(cargo.route_specification, cargo.itinerary, handling_history)
  end

  def assign_cargo_to_route(cargo, itinerary) when is_map(itinerary) do
    # Handling consistency within the Cargo aggregate synchronously
    maybe_delivery = Map.get(cargo, :delivery, Map.get(cargo, "delivery"))

    delivery =
      maybe_delivery
      |> Delivery.update_on_routing(cargo.route_specification, itinerary)

    %{itinerary: itinerary, delivery: delivery}
  end

  def specify_new_route(cargo, route_specification) do
    delivery = Delivery.update_on_routing(nil, route_specification, cargo.itinerary)

    %{route_specification: route_specification, delivery: delivery}
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
    HandlingEvent.changeset(cargo, attrs)
    |> Repo.insert()
  end

  def create_handling_event_from_report(attrs \\ %{}) do
    HandlingEvent.handling_report_changeset(attrs)
    |> Repo.insert()
  end
end

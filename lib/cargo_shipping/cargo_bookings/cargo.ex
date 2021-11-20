defmodule CargoShipping.CargoBookings.Cargo do
  @moduledoc """
  The root of the Cargo-Itinerary-Leg-Delivery-RouteSpecification AGGREGATE.

  Cargo is the central class in the domain model.

  A Cargo is identified by a unique `tracking_id`, and it always has an `origin`
  and a `RouteSpecification`. The life cycle of a Cargo begins with the booking procedure,
  when the `tracking_id` is assigned. During a (short) period of time, between booking
  and initial routing, the Cargo has no `Itinerary`.

  The booking clerk requests a list of possible routes, matching the route specification,
  and assigns the Cargo to one route. The route to which a Cargo is assigned is described
  by an `Itinerary`.

  A Cargo can be re-routing_status during transport, on demand of the customer, in which case
  a new route is specified for the Cargo and a new route is requested. The old itinerary,
  being a value object, is discarded and a new one is attached.

  It may also happen that a Cargo is accidentally misrouted, which should notify the proper
  personnel and also trigger a re-routing procedure.

  When a Cargo is handled, the status of the delivery changes. Everything about the delivery
  of the Cargo is contained in the Delivery value object, which is replaced whenever a Cargo
  is handled by an asynchronous event triggered by the registration of the handling event.

  The delivery can also be affected by routing changes, i.e. when the route specification
  changes, or the Cargo is assigned to a new route. In that case, the delivery update is performed
  synchronously within the Cargo aggregate.

  The life cycle of a Cargo ends when the Cargo is claimed by the customer.

  The Cargo aggregate, and the entire domain model, is built to solve the problem
  of booking and tracking cargo. All important business rules for determining whether
  or not a cargo is misdirected, what the current status of the cargo is (on board carrier,
  in port etc), are captured in this aggregate.
  """
  import Ecto.Changeset

  alias CargoShipping.CargoBookings.{Delivery, Itinerary, RouteSpecification}

  defmodule EditDestination do
    @moduledoc """
    Use a schemaless changeset to build edit destination form.
    """
    use Ecto.Schema

    alias CargoShipping.Locations

    @primary_key false
    embedded_schema do
      field :destination, :string
      field :arrival_deadline, :utc_datetime
    end

    def changeset(destination, attrs) do
      destination
      |> cast(attrs, [:destination, :arrival_deadline])
      |> Locations.validate_location_code(:destination)
    end
  end

  @doc false
  def changeset(cargo, attrs) do
    cargo
    |> cast(attrs, [:tracking_id])
    |> validate_required([:tracking_id])
    |> validate_format(:tracking_id, ~r/^[A-Z]{3,}[0-9]{0,6}$/,
      message: "should be at least 3 uppercase letters, optionally followed by up to 6 digits"
    )
    |> unique_constraint(:tracking_id)
    |> cast_embed(:route_specification, with: &RouteSpecification.changeset/2)
    |> cast_embed(:itinerary, with: &Itinerary.changeset/2)
    |> cast_embed(:delivery, with: &Delivery.changeset/2)
  end

  def version_changeset(cargo, attrs) do
    current_version = cargo.version

    cargo
    |> changeset(attrs)
    |> set_created_version(current_version)
  end

  defp set_created_version(changeset, current_version) do
    cond do
      is_nil(current_version) ->
        changeset

      !is_nil(get_field(changeset, :created_version)) ->
        changeset

      true ->
        put_change(changeset, :created_version, current_version)
    end
  end
end

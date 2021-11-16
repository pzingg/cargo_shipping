defmodule CargoShippingSchemas.Cargo do
  @moduledoc """
  The root of the Cargo-Itinerary-Leg-Delivery-RouteSpecification AGGREGATE.
  """
  use Ecto.Schema

  alias CargoShippingSchemas.{Delivery, HandlingEvent, Itinerary, RouteSpecification}

  @derive {Phoenix.Param, key: :tracking_id}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "cargos" do
    field :tracking_id, :string
    field :origin, :string
    embeds_one :route_specification, RouteSpecification, on_replace: :update
    embeds_one :itinerary, Itinerary, on_replace: :update
    embeds_one :delivery, Delivery, on_replace: :update

    has_many(:handling_events, HandlingEvent)

    timestamps()
  end
end

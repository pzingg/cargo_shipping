defmodule CargoShippingSchemas.Cargo do
  @moduledoc """
  The root of the Cargo-Itinerary-Leg-Delivery-RouteSpecification AGGREGATE.
  """
  use Ecto.Schema

  alias CargoShippingSchemas.{Delivery, HandlingEvent, Itinerary, RouteSpecification}

  # @derive macro blows up boundary checking
  # Error: (references from CargoShippingSchemas to Phoenix.Param.Any are not allowed)
  # @derive {Phoenix.Param, key: :tracking_id}

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

  # Same as @derive {Phoenix.Param, key: :tracking_id}
  defimpl Phoenix.Param, for: __MODULE__ do
    def to_param(tracking_id: key) when is_binary(key), do: key

    def to_param(tracking_id: nil) do
      raise ArgumentError,
            "cannot convert #{inspect(__MODULE__)} to param, " <>
              "key :tracking_id contains a nil value"
    end

    def to_param(tracking_id: _key) do
      raise ArgumentError,
            "cannot convert #{inspect(__MODULE__)} to param, " <>
              "key :tracking_id contains a non-binary value"
    end
  end
end

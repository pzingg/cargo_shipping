defmodule CargoShippingSchemas.Voyage do
  @moduledoc """
  The root* of the Voyages AGGREGATE*.
  From the DDD book: [An AGGREGATE is] a cluster of associated objects that
  are treated as a unit for the purgpose of data changes. External references are
  restricted to one member of the AGGREGATE, designated as the root.
  """
  use Ecto.Schema

  alias CargoShippingSchemas.CarrierMovement

  # @derive macro blows up boundary checking
  # Error: (references from CargoShippingSchemas to Phoenix.Param.Any are not allowed)
  # @derive {Phoenix.Param, key: :voyage_number}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "voyages" do
    field :voyage_number, :string
    embeds_many :schedule_items, CarrierMovement, on_replace: :delete

    timestamps()
  end

  # Same as @derive {Phoenix.Param, key: :voyage_number}
  defimpl Phoenix.Param, for: __MODULE__ do
    def to_param(voyage_number: key) when is_binary(key), do: key

    def to_param(voyage_number: nil) do
      raise ArgumentError,
            "cannot convert #{inspect(__MODULE__)} to param, " <>
              "key :voyage_number contains a nil value"
    end

    def to_param(voyage_number: _key) do
      raise ArgumentError,
            "cannot convert #{inspect(__MODULE__)} to param, " <>
              "key :voyage_number contains a non-binary value"
    end
  end
end

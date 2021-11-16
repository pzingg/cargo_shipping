defmodule CargoShippingSchemas.Voyage do
  @moduledoc """
  The root* of the Voyages AGGREGATE*.
  From the DDD book: [An AGGREGATE is] a cluster of associated objects that
  are treated as a unit for the purgpose of data changes. External references are
  restricted to one member of the AGGREGATE, designated as the root.
  """
  use Ecto.Schema

  alias CargoShippingSchemas.CarrierMovement

  @derive {Phoenix.Param, key: :voyage_number}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "voyages" do
    field :voyage_number, :string
    embeds_many :schedule_items, CarrierMovement, on_replace: :delete

    timestamps()
  end
end

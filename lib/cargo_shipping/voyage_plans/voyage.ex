defmodule CargoShipping.VoyagePlans.Voyage do
  @moduledoc """
  The root* of the Voyages AGGREGATE*.
  From the DDD book: [An AGGREGATE is] a cluster of associated objects that
  are treated as a unit for the purgpose of data changes. External references are
  restricted to one member of the AGGREGATE, designated as the root.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.VoyagePlans.CarrierMovement

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]
  schema "voyages" do
    field :voyage_number, :integer
    embeds_many :schedule_items, CarrierMovement, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(voyage, attrs) do
    voyage
    |> cast(attrs, [:voyage_number])
    |> validate_required([:voyage_number])
    |> cast_embed(:schedule_items, with: &CarrierMovement.changeset/2)
  end
end

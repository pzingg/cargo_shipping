defmodule CargoShipping.VoyagePlans.Voyage do
  @moduledoc """
  The root* of the Voyages AGGREGATE*.
  From the DDD book: [An AGGREGATE is] a cluster of associated objects that
  are treated as a unit for the purgpose of data changes. External references are
  restricted to one member of the AGGREGATE, designated as the root.
  """
  import Ecto.Changeset

  alias CargoShipping.VoyagePlans.CarrierMovement

  @doc false
  def changeset(voyage, attrs) do
    voyage
    |> cast(attrs, [:voyage_number])
    |> validate_required([:voyage_number])
    |> validate_length(:voyage_number, min: 4, max: 10)
    |> unique_constraint(:voyage_number)
    |> cast_embed(:schedule_items, with: &CarrierMovement.changeset/2)
  end

  def validate_contiguous_items(changeset) do
    {next_changeset, _} =
      get_field(changeset, :schedule_items)
      |> Enum.reduce_while({changeset, nil}, fn item, {cs, last_item} ->
        if is_nil(last_item) || last_item.arrival_location == item.departure_location do
          {:cont, {cs, item}}
        else
          {:halt, {add_error(cs, :schedule_items, "are not contiguous"), item}}
        end
      end)

    next_changeset
  end
end

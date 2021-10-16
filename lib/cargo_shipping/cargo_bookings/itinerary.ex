defmodule CargoShipping.CargoBookings.Itinerary do
  @moduledoc """
  A VALUE OBJECT.

  An Itinerary consists of one or more Legs.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.CargoBookings.Leg

  embedded_schema do
    field :itinerary_number, :integer
    embeds_many :legs, Leg, on_replace: :delete
  end

  @doc false
  def changeset(itinerary, attrs) do
    itinerary
    |> cast(attrs, [:itinerary_number])
    |> validate_required([:itinerary_number])
    |> cast_embed(:legs, with: &Leg.changeset/2)
  end
end

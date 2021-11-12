defmodule CargoShippingSchemas.Itinerary do
  @moduledoc """
  A VALUE OBJECT.

  An Itinerary consists of one or more Legs.
  """
  use Ecto.Schema

  alias CargoShippingSchemas.Leg

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    embeds_many :legs, Leg, on_replace: :delete
  end
end

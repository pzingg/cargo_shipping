defmodule CargoShippingSchemas.Location do
  @moduledoc """
  A struct representing a location.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :port_code, :string
    field :name, :string
  end
end

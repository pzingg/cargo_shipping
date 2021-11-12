defmodule CargoShippingSchemas.Bulletin do
  @moduledoc """
  Support "toasty" messages.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :level, :string
    field :message, :string
  end
end

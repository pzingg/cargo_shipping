defmodule CargoShipping.Locations.Location do
  @moduledoc """
  A struct representing a location.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :port_code, :string
    field :name, :string
  end

  def new(port_code, name) do
    %__MODULE__{}
    |> changeset(%{port_code: port_code, name: name})
    |> apply_changes()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:port_code, :name])
    |> validate_required([:port_code, :name])
  end
end

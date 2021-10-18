defmodule CargoShipping.Locations.Location do
  @moduledoc """
  A struct representing a location.
  """
  use TypedStruct

  import Ecto.Changeset

  typedstruct do
    @typedoc "A person"
    plugin(TypedStructEctoChangeset)

    field :id, String.t(), enforce: true
    field :name, String.t(), enforce: true
    field :port_code, String.t(), enforce: true
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:id, :port_code, :name])
    |> validate_required([:id, :port_code, :name])
  end
end

defmodule CargoShipping.Locations.Location do
  @moduledoc """
  A struct representing a location.
  """
  import Ecto.Changeset

  def new(port_code, name) do
    %CargoShippingSchemas.Location{}
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

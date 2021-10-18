defmodule CargoShipping.VoyagePlans.CarrierMovement do
  @moduledoc """
  A VALUE OBJECT.
  """
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :departure_location, :string
    field :arrival_location, :string
    field :departure_time, :utc_datetime
    field :arrival_time, :utc_datetime
    field :delete, :string, virtual: true
  end

  @doc false
  def changeset(carrier_movement, attrs) do
    carrier_movement
    |> cast(attrs, [
      :departure_location,
      :arrival_location,
      :departure_time,
      :arrival_time,
      :delete
    ])
    |> validate_required([:departure_location, :arrival_location, :departure_time, :arrival_time])
  end
end

defmodule CargoShipping.CargoBookings.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :voyage_id, Ecto.UUID
    field :load_location, :string
    field :unload_location, :string
    field :load_time, :utc_datetime
    field :unload_time, :utc_datetime
  end

  @doc false
  def changeset(leg, attrs) do
    leg
    |> cast(attrs, [:voyage_id, :load_location, :unload_location, :load_time, :unload_time])
    |> validate_required([:voyage_id, :load_time, :unload_time])
  end
end

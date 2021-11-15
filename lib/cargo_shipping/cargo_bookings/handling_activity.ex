defmodule CargoShipping.CargoBookings.HandlingActivity do
  @moduledoc """
  A VALUE OBJECT.

  A HandlingActivity represents how and where a cargo can be handled,
  and can be used to express predictions about what is expected to
  happen to a cargo in the future.
  """
  import Ecto.Changeset

  alias CargoShippingSchemas.HandlingEvent

  @doc false
  def changeset(handling_activity, attrs) do
    handling_activity
    |> cast(attrs, [:event_type, :location, :voyage_id])
    |> validate_required([:event_type, :location])
    |> validate_inclusion(:event_type, HandlingEvent.event_type_values())
  end
end

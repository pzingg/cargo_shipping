defmodule CargoShipping.CargoBookings.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.VoyageService

  @status_values [:NOT_LOADED, :SKIPPED, :ONBOARD_CARRIER, :COMPLETED, :CLAIMED]

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :status, Ecto.Enum, values: @status_values
    field :voyage_id, Ecto.UUID
    field :load_location, :string
    field :unload_location, :string
    field :load_time, :utc_datetime
    field :unload_time, :utc_datetime
  end

  @cast_fields [
    :status,
    :voyage_id,
    :load_location,
    :unload_location,
    :load_time,
    :unload_time
  ]

  @required_fields [
    :status,
    :voyage_id,
    :load_location,
    :unload_location,
    :load_time,
    :unload_time
  ]

  @doc false
  def changeset(leg, attrs) do
    leg
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @status_values)
    |> validate_voyage_item()
  end

  def validate_voyage_item(changeset) do
    voyage_id = get_field(changeset, :voyage_id)
    load_location = get_field(changeset, :load_location)
    unload_location = get_field(changeset, :unload_location)

    case VoyageService.check_leg_in_voyage(voyage_id, load_location, unload_location) do
      :ok ->
        changeset

      {:error, key, message} ->
        add_error(changeset, key, message)
    end
  end
end

defmodule CargoShipping.CargoBookings.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.CargoBookings.RouteSpecification
  alias CargoShipping.VoyageService

  @status_values [:NOT_LOADED, :ONBOARD_CARRIER, :SKIPPED, :COMPLETED, :CLAIMED]
  @completed_values [:SKIPPED, :COMPLETED, :CLAIMED]

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
    if Enum.member?(@completed_values, get_field(changeset, :status, :NOT_LOADED)) do
      changeset
    else
      voyage_id = get_field(changeset, :voyage_id)

      route_specification = %RouteSpecification{
        origin: get_field(changeset, :load_location),
        destination: get_field(changeset, :unload_location)
      }

      case VoyageService.find_items_for_route_specification(voyage_id, route_specification) do
        {:ok, _items} ->
          changeset

        {:error, key, message} ->
          add_error(changeset, leg_key_for(key), message)
      end
    end
  end

  @doc """
  Note: leg may NOT have status set (equivalent to :NOT_LOADED).
  """
  def completed?(%{status: :SKIPPED}), do: true
  def completed?(%{status: :COMPLETED}), do: true
  def completed?(%{status: :CLAIMED}), do: true
  def completed?(_leg), do: false

  defp leg_key_for(:origin), do: :load_location
  defp leg_key_for(:destination), do: :unload_location
  defp leg_key_for(other_key), do: other_key
end

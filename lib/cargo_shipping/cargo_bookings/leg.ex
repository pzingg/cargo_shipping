defmodule CargoShipping.CargoBookings.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias CargoShipping.CargoBookings.RouteSpecification
  alias CargoShipping.VoyageService
  alias __MODULE__

  @status_values [:NOT_LOADED, :ONBOARD_CARRIER, :SKIPPED, :COMPLETED, :IN_CUSTOMS, :CLAIMED]
  @completed_values [:SKIPPED, :COMPLETED, :IN_CUSTOMS, :CLAIMED]

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :status, Ecto.Enum, values: @status_values
    field :voyage_id, Ecto.UUID
    field :load_location, :string
    field :unload_location, :string
    field :actual_load_location, :string
    field :actual_unload_location, :string
    field :load_time, :utc_datetime
    field :unload_time, :utc_datetime
  end

  defimpl String.Chars, for: Leg do
    @doc """
    :actual_load_location, :actual_unload_location may be missing
    """
    def to_string(leg) do
      voyage_number =
        VoyageService.get_voyage_number_for_id!(leg.voyage_id)
        |> String.pad_trailing(6)

      status = Map.get(leg, :status, :NOT_LOADED)

      load_location =
        case Map.get(leg, :actual_load_location) do
          nil -> leg.load_location
          location -> "#{location} (ACTUAL)"
        end

      unload_location =
        case Map.get(leg, :actual_unload_location) do
          nil -> leg.unload_location
          location -> "#{location} (ACTUAL)"
        end

      "on voyage #{voyage_number} from #{load_location} to #{unload_location} - #{status}"
    end
  end

  @cast_fields [
    :status,
    :voyage_id,
    :load_location,
    :unload_location,
    :actual_load_location,
    :actual_unload_location,
    :load_time,
    :unload_time
  ]

  @required_fields [
    :status,
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
    status = get_field(changeset, :status, :NOT_LOADED)
    actual_unload_location = get_field(changeset, :actual_unload_location)

    if requires_voyage_id?(status, actual_unload_location) do
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
    else
      changeset
    end
  end

  @doc """
  Note: leg may NOT have status set (equivalent to :NOT_LOADED).
  """
  def completed?(leg), do: Enum.member?(@completed_values, Map.get(leg, :status, :NOT_LOADED))

  def unexpected_load?(leg) do
    !is_nil(Map.get(leg, :actual_load_location))
  end

  def unexpected_unload?(leg) do
    !is_nil(Map.get(leg, :actual_unload_location))
  end

  def actual_load_location(leg) do
    Map.get(leg, :actual_load_location) || leg.load_location
  end

  def actual_unload_location(leg) do
    Map.get(leg, :actual_unload_location) || leg.unload_location
  end

  defp requires_voyage_id?(status, actual_unload_location) do
    status == :NOT_LOADED || is_binary(actual_unload_location)
  end

  defp leg_key_for(:origin), do: :load_location
  defp leg_key_for(:destination), do: :unload_location
  defp leg_key_for(other_key), do: other_key
end

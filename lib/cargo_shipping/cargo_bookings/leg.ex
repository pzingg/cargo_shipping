defmodule CargoShipping.CargoBookings.Leg do
  @moduledoc """
  A VALUE OBJECT.

  A Leg of an Itinerary.
  """
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  alias CargoShipping.VoyageService
  alias CargoShippingSchemas.Leg
  alias CargoShippingSchemas.RouteSpecification

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

  defimpl String.Chars, for: CargoShippingSchemas.Leg do
    use Boundary, classify_to: CargoShipping

    def to_string(leg) do
      CargoShipping.CargoBookings.Leg.string_from(leg)
    end
  end

  @doc """
  :actual_load_location, :actual_unload_location may be missing
  """
  def string_from(leg) do
    voyage_number =
      VoyageService.get_voyage_number_for_id(leg.voyage_id)
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

  @doc false
  def changeset(leg, attrs) do
    leg
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, Leg.status_values())
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
  def unexpected_load?(leg) do
    !is_nil(Map.get(leg, :actual_load_location))
  end

  def unexpected_unload?(leg) do
    !is_nil(Map.get(leg, :actual_unload_location))
  end

  # Note: leg may NOT have status set (equivalent to :NOT_LOADED).
  def debug_leg(leg) do
    Logger.debug("  #{string_from(leg)}")
  end

  defp requires_voyage_id?(status, actual_unload_location) do
    status == :NOT_LOADED || is_binary(actual_unload_location)
  end

  defp leg_key_for(:origin), do: :load_location
  defp leg_key_for(:destination), do: :unload_location
  defp leg_key_for(other_key), do: other_key
end

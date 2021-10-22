defmodule CargoShipping.Utils do
  @moduledoc false

  @doc """
  Recursively remove struct and schema information
  """
  def from_struct(%Ecto.Association.NotLoaded{} = _v), do: nil

  def from_struct(v) when is_list(v) do
    Enum.map(v, fn item -> from_struct(item) end)
  end

  def from_struct(v) when is_map(v) do
    Map.delete(v, :__struct__)
    |> Map.delete(:__meta__)
    |> Enum.map(fn {k, v} -> {k, from_struct(v)} end)
    |> Enum.into(%{})
  end

  def from_struct(v), do: v
end

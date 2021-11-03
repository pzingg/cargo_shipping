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
    from_struct_0(v)
    |> Enum.map(fn {k, v} -> {k, from_struct(v)} end)
    |> Enum.into(%{})
  end

  def from_struct(v), do: v

  def from_struct_0(v) when is_map(v) do
    Map.delete(v, :__struct__)
    |> Map.delete(:__meta__)
  end

  def atom_keys?(attrs) do
    from_struct_0(attrs) |> Enum.any?(fn {k, _v} -> is_atom(k) end)
  end

  def get(attrs, atom_key) do
    if atom_keys?(attrs) do
      Map.get(attrs, atom_key)
    else
      Map.get(attrs, Atom.to_string(atom_key))
    end
  end

  def pop(attrs, atom_key) do
    if atom_keys?(attrs) do
      Map.pop(attrs, atom_key)
    else
      Map.pop(attrs, Atom.to_string(atom_key))
    end
  end
end

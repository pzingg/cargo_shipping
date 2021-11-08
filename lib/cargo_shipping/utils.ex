defmodule CargoShipping.Utils do
  @moduledoc false

  @doc """
  Recursively change string keys to atoms.
  """
  def atomize(%{__struct__: _} = v), do: v

  def atomize(v) when is_list(v) do
    Enum.map(v, fn item -> atomize(item) end)
  end

  def atomize(v) when is_map(v) do
    atomize_0(v)
    |> Enum.map(fn {k, v} -> {k, atomize(v)} end)
    |> Enum.into(%{})
  end

  def atomize(v), do: v

  def atomize_0(v) when is_map(v) do
    Enum.map(v, fn
      {k, v} when is_atom(k) -> {k, v}
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
    end)
    |> Enum.into(%{})
  end

  def atomize_0(v), do: v

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

  def from_struct_0(%{__struct__: _} = v) do
    Map.delete(v, :__struct__)
    |> Map.delete(:__meta__)
  end

  def from_struct_0(v), do: v

  @doc """
  Detect if params have atom keys or string keys.
  """
  def atom_keys?(attrs) do
    from_struct_0(attrs) |> Enum.any?(fn {k, _v} -> is_atom(k) end)
  end

  @doc """
  Get a value from a map by atom key or string key.
  """
  def get(attrs, atom_key) do
    if atom_keys?(attrs) do
      Map.get(attrs, atom_key)
    else
      Map.get(attrs, Atom.to_string(atom_key))
    end
  end

  @doc """
  Pop a value from a map by atom key or string key.
  """
  def pop(attrs, atom_key) do
    if atom_keys?(attrs) do
      Map.pop(attrs, atom_key)
    else
      Map.pop(attrs, Atom.to_string(atom_key))
    end
  end

  ## Changeset helpers

  def maybe_mark_for_deletion(%{data: %{id: nil}} = changeset), do: changeset

  def maybe_mark_for_deletion(changeset) do
    if Ecto.Changeset.get_change(changeset, :delete) do
      %{changeset | action: :delete}
    else
      changeset
    end
  end

  def get_temp_id() do
    :crypto.strong_rand_bytes(5) |> Base.url_encode64() |> binary_part(0, 5)
  end
end

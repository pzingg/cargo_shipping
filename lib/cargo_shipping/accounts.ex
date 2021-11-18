defmodule CargoShipping.Accounts do
  @moduledoc """
  A mock Accounts context.
  """

  @rand_size 32
  @confirmed_at ~U[2021-09-01 12:00:00Z]

  @mock_users [
    %{
      id: 1,
      email: "manager@phoenixcargo.com",
      role: :manager,
      confirmed_at: @confirmed_at
    },
    %{id: 2, email: "clerk@phoenixcargo.com", role: :clerk, confirmed_at: @confirmed_at}
  ]

  @doc """
  Gets a single user.

  Raises `RuntimeError` if the User does not exist.

  ## Examples

      iex> get_user!(1)
      %{id: 1, email: ..., role: ..., confirmed_at: ...}

      iex> get_user!(456)
      ** (RuntimeError)

  """
  def get_user!(id) do
    case Enum.find(@mock_users, fn user -> user.id == id end) do
      nil -> raise RuntimeError
      user -> user
    end
  end

  @doc """
  Gets a single user.

  ## Examples

      iex> get_user_by_role("manager")
      %{id: 1, email: ..., role: :manager, confirmed_at: ...}

      iex> get_user_by_role("superman")
      nil

  """
  def get_user_by_role(role) do
    role = String.to_existing_atom(role)
    Enum.find(@mock_users, fn user -> user.role == role end)
  end

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    "#{user.id}___#{:crypto.strong_rand_bytes(@rand_size)}"
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    [user_id, _rand_bytes] = String.split(token, "___", parts: 2)
    String.to_integer(user_id) |> get_user!()
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(_token) do
    :ok
  end
end

defmodule CargoShippingWeb.InitAssigns do
  @moduledoc """
  Mock module for LiveView authentication.
  """
  import Phoenix.LiveView

  require Logger

  alias CargoShipping.Accounts
  alias CargoShippingWeb.UserAuth

  @doc """
  Set up assigns at mount time for every live view.
  """
  def on_mount(mount_arg, params, session, socket) do
    Logger.error("on_mount mount_arg: #{mount_arg}")
    Logger.error("  session: #{inspect(session)}")
    Logger.error("  assigns: #{inspect(socket.assigns)}")

    socket =
      socket
      |> assign(:bulletins, nil)
      |> assign_time_zone(params)
      |> assign_current_user(session)

    Logger.error("  result: #{inspect(socket.assigns)}")

    current_user = socket.assigns.current_user

    case {mount_arg, current_user} do
      {:manager, %{role: :manager}} ->
        {:cont, socket}

      {:clerk, %{role: :manager}} ->
        {:cont, socket}

      {:clerk, %{role: :clerk}} ->
        {:cont, socket}

      {:default, _} ->
        {:cont, socket}

      _ ->
        {:halt, redirect(socket, to: UserAuth.landing_path_for(socket, current_user))}
    end
  end

  defp assign_current_user(socket, session) do
    assign_new(socket, :current_user, fn -> get_current_user(session) end)
  end

  defp get_current_user(%{"user_token" => user_token}) do
    Accounts.get_user_by_session_token(user_token)
  end

  defp get_current_user(_session), do: nil

  defp assign_time_zone(socket, params) do
    if Phoenix.LiveView.connected?(socket) do
      assign_new(socket, :tz, fn -> get_time_zone(socket, params) end)
    else
      socket
    end
  end

  # tz param is set in app.js
  defp get_time_zone(socket, params) do
    Map.get(params, "tz") ||
      Phoenix.LiveView.get_connect_params(socket)
      |> Map.get("tz", "Etc/UTC")
  end
end

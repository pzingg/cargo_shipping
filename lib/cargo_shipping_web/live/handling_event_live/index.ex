defmodule CargoShippingWeb.HandlingEventLive.Index do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))}
  end

  defp page_title(:index), do: "Handling Events"
end

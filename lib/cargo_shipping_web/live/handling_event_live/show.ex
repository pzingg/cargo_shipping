defmodule CargoShippingWeb.HandlingEventLive.Show do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:project, CargoBookings.get_handling_event!(id))}
  end

  defp page_title(:show), do: "Handling Event"
end

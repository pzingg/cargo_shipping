defmodule CargoShippingWeb.CargoLive.Show do
  use CargoShippingWeb, :live_view

  alias CargoShipping.CargoBookings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(%{"tracking_id" => tracking_id}, _uri, socket) do
    cargo = CargoBookings.get_cargo_by_tracking_id!(tracking_id, with_events: true)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(
       handling_events: cargo.handling_events,
       tracking_id: cargo.tracking_id,
       cargo: cargo
     )}
  end

  defp page_title(:show), do: "Cargo"
end

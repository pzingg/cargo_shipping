defmodule CargoShippingWeb.VoyageLive.Index do
  use CargoShippingWeb, :live_view

  alias CargoShipping.VoyagePlans

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:header, "All voyages")
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:voyages, VoyagePlans.list_voyages())}
  end

  def page_title(:index), do: "All voyages"
end

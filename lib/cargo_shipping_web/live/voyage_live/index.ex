defmodule CargoShippingWeb.VoyageLive.Index do
  use CargoShippingWeb, :live_view

  alias CargoShipping.VoyagePlans

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    title = page_title(socket.assigns.live_action)

    {:noreply,
     socket
     |> assign(
       header: title,
       page_title: title,
       voyages: VoyagePlans.list_voyages()
     )}
  end

  def page_title(:index), do: "All voyages"
end

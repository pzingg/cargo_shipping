defmodule CargoShippingWeb.CargoLive.RouteFormComponent do
  use CargoShippingWeb, :live_component

  @impl true
  def update(%{index: index} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:title, "Route candidate #{index}")}
  end
end

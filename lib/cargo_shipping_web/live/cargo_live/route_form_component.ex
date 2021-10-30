defmodule CargoShippingWeb.CargoLive.RouteFormComponent do
  use CargoShippingWeb, :live_component

  require Logger

  alias CargoShipping.CargoBookings.Cargo

  @impl true
  def update(%{id: id, index: index} = assigns, socket) do
    changeset =
      %Cargo.EditRoute{id: id}
      |> Cargo.EditRoute.changeset(%{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:title, "Route candidate #{index}")}
  end
end

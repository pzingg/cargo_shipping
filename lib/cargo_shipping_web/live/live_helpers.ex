defmodule CargoShippingWeb.LiveHelpers do
  import Phoenix.LiveView.Helpers

  alias CargoShipping.CargoBookings.Cargo
  alias CargoShipping.Locations.LocationService

  @doc """
  Renders a component inside the `Example16Web.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal Example16Web.ProjectLive.FormComponent,
        id: @project.id || :new,
        action: @live_action,
        project: @project,
        return_to: Routes.project_index_path(@socket, :index) %>
  """
  def live_modal(component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    live_component(CargoShippingWeb.ModalComponent, modal_opts)
  end

  def default_assigns(socket) do
    socket
  end

  def location_name(location) do
    LocationService.get_by_port_code(location).name
  end

  def cargo_origin(cargo) do
    cargo.origin |> location_name()
  end

  def cargo_final_destination(cargo) do
    Cargo.final_destination(cargo) |> location_name()
  end

  def cargo_routed(cargo), do: Cargo.routed(cargo)
end

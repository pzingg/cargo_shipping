defmodule CargoShippingWeb.VoyageLive.Show do
  @moduledoc false
  use CargoShippingWeb, :live_view

  alias CargoShipping.VoyagePlans

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"voyage_number" => voyage_number} = params, _uri, socket) do
    voyage = VoyagePlans.get_voyage_by_number!(voyage_number)

    {back_link_label, back_link_path} =
      case {Map.get(params, "back_link_label"), Map.get(params, "back_link_path")} do
        {label, path} when is_binary(label) and is_binary(path) -> {label, path}
        _ -> {"All voyages", Routes.voyage_index_path(socket, :index)}
      end

    {:noreply,
     socket
     |> assign(
       page_title: page_title(voyage.voyage_number, socket.assigns.live_action),
       voyage_number: voyage.voyage_number,
       voyage: voyage,
       back_link_label: back_link_label,
       back_link_path: back_link_path,
       return_to: back_link_path
     )}
  end

  defp page_title(voyage_number, :show), do: "Voyage #{voyage_number}"
end

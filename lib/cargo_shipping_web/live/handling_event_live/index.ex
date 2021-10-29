defmodule CargoShippingWeb.HandlingEventLive.Index do
  use CargoShippingWeb, :live_view

  require Logger

  alias CargoShipping.CargoBookings

  @impl true
  def mount(params, session, socket) do
    Logger.error("HandlingEventLive.mount #{inspect(params)} #{inspect(session)}")
    {:ok, socket |> default_assigns()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    Logger.error("HandlingEventLive.handle_params #{inspect(params)}")

    tracking_id = Map.get(params, "tracking_id")

    handling_events =
      if is_nil(tracking_id) do
        CargoBookings.list_handling_events()
      else
        CargoBookings.lookup_handling_history(tracking_id)
      end

    {:noreply,
     socket
     |> assign(:handling_events, handling_events)
     |> assign(:page_title, page_title(tracking_id))}
  end

  defp page_title(nil), do: "All Handling Events"
  defp page_title(tracking_id), do: "Handling Events for Cargo #{tracking_id}"
end

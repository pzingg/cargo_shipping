defmodule CargoShippingWeb.CargoLive.ItineraryComponents do
  @moduledoc """
  Components for displaying and selecting itineraries.
  """
  use Phoenix.Component

  import CargoShippingWeb.LiveHelpers

  @doc """
  Required assign: :indexed_legs, :selected_index
  """
  def show_itinerary(assigns) do
    ~H"""
    <table>
      <thead>
        <tr>
          <th>Status</th>
          <th>Voyage</th>
          <th>Load in</th>
          <th>Date</th>
          <th>Unload in</th>
          <th>Date</th>
        </tr>
      </thead>
      <tbody id="itinerary-legs">
        <%= for {leg, i} <- @indexed_legs do %>
          <tr class={class_highlight(i == @selected_index)} id={"leg-#{leg.load_location}-#{leg.unload_location}"}>
            <td><%= leg.status %></td>
            <td><%= voyage_number_for(leg) %></td>
            <td><%= location_name(leg.load_location) %></td>
            <td><%= event_time(leg, :load_time) %></td>
            <td><%= location_name(leg.unload_location) %></td>
            <td><%= event_time(leg, :unload_time) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  @doc """
  Required assigns: :title, :index, :is_internal, :indexed_legs
  """
  def select_itinerary_form(assigns) do
    ~H"""
    <div>
      <h2><%= @title %></h2>

      <%= if @is_internal do %>
      <p>This itinerary does not require a change of voyages from the current itinerary.</p>
      <% end %>

      <.show_itinerary indexed_legs={@indexed_legs} selected_index={-1} />

      <div id="route-form-#{@index}">
        <button type="button"
          phx-click="save"
          phx-value-index={@index}
          phx-disable-with="Processing...">
          Assign cargo to this route
        </button>
      </div>
    </div>
    """
  end

  defp class_highlight(false), do: ""
  defp class_highlight(_), do: "current-row"
end

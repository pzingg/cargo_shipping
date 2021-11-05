defmodule CargoShippingWeb.CargoLive.ItineraryComponents do
  @moduledoc """
  Components for displaying and selecting itineraries.
  """
  use CargoShippingWeb, :component

  import CargoShippingWeb.LiveHelpers

  @doc """
  Required assign: :socket, :back_link_label, :back_link_path, :indexed_legs, :selected_index
  """
  def show_itinerary(assigns) do
    ~H"""
    <table>
      <thead>
        <tr>
          <th>Status</th>
          <th>Voyage</th>
          <th>Load at</th>
          <th>Date</th>
          <th>Unload at</th>
          <th>Date</th>
        </tr>
      </thead>
      <tbody id="itinerary-legs">
        <%= for {leg, i} <- @indexed_legs do %>
          <tr class={class_highlight(i == @selected_index)} id={"leg-#{leg.load_location}-#{leg.unload_location}"}>
            <td><%= leg.status %></td>
            <td><%= voyage_link_for(leg, @socket, @back_link_label, @back_link_path) %></td>
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
  Required assigns: :socket, :title, :back_link_label, :back_link_path, :index, :is_internal, :indexed_legs
  """
  def select_itinerary_form(assigns) do
    ~H"""
    <div>
      <h2><%= @title %></h2>

      <%= if @is_internal do %>
      <p>This itinerary does not require a change of voyages from the current itinerary.</p>
      <% end %>

      <.show_itinerary socket={@socket} back_link_label={@back_link_label} back_link_path={@back_link_path}
        indexed_legs={@indexed_legs} selected_index={-1} />

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

  @doc """
  Required assign: :items
  """
  def show_voyage_items(assigns) do
    ~H"""
    <table>
      <thead>
        <tr>
          <th>Departs from</th>
          <th>Date</th>
          <th>Arrives at</th>
          <th>Date</th>
        </tr>
      </thead>
      <tbody id="voyage-items">
        <%= for item <- @items do %>
          <tr id={"item-#{item.departure_location}-#{item.arrival_location}"}>
            <td><%= location_name(item.departure_location) %></td>
            <td><%= event_time(item, :departure_time) %></td>
            <td><%= location_name(item.arrival_location) %></td>
            <td><%= event_time(item, :arrival_time) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp class_highlight(false), do: ""
  defp class_highlight(_), do: "current-row"
end

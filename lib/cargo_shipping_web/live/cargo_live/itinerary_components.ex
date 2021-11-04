defmodule CargoShippingWeb.CargoLive.ItineraryComponents do
  @moduledoc """
  Components for displaying and selecting itineraries.
  """
  use Phoenix.Component

  import CargoShippingWeb.LiveHelpers

  @doc """
  Required assign: :legs
  """
  def show_itinerary(assigns) do
    ~H"""
    <table>
      <thead>
        <tr>
          <th>Voyage</th>
          <th>Load in</th>
          <th>Date</th>
          <th>Unload in</th>
          <th>Date</th>
        </tr>
      </thead>
      <tbody id="itinerary-legs">
        <%= for leg <- @legs do %>
          <tr id={"leg-#{leg.load_location}-#{leg.unload_location}"}>
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
  Required assigns: :title, :itinerary, :index
  """
  def select_itinerary_form(assigns) do
    ~H"""
    <div>
      <h2><%= @title %></h2>

      <.show_itinerary legs={@itinerary.legs} />

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
end

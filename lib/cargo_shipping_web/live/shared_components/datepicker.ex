defmodule CargoShippingWeb.SharedComponents.Datepicker do
  @moduledoc """
  Pure Phoenix Datepicker component, adapted from https://github.com/aej/liveview_datepicker

  Required parameters:

  * :id - The unique id, from `input_id(f, :field)`.
  * :target_name - The name of the field, from `input_name(f, :field)`.

  Optional parameters:

  * :max_date (default false) - If set to a %Date{} value, only dates less than or equal to the date
    can be selected. If set to true, only dates less than or equal to today's date can be selected.
  * :selected_date - If set to a %Date{} or %DateTime{} value, the initial date for the picker,
    otherwise the value of DateTime.utc_now() will be used.
  """
  use CargoShippingWeb, :live_component

  require Logger

  @hour_options [
    "00",
    "01",
    "02",
    "03",
    "04",
    "05",
    "06",
    "07",
    "08",
    "09",
    "10",
    "11",
    "12",
    "13",
    "14",
    "15",
    "16",
    "17",
    "18",
    "19",
    "20",
    "21",
    "22",
    "23"
  ]
  @minute_options ["00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"]

  @doc """
  If the live component is embedded in a <form> element in a live view (the normal use case),
  and a user clicks on the hour or time select input, a "phx-change" event will
  be sent to parent live view.

  `inputs` can be either a single field or a list of fields.

  Each field is either the field name as a string for non-nested fields,
  or a 2-tuple of the  collection name and field name both as strings, for
  nested fields.

  Example `"arrival_deadline"` for a single non-nested field, or
  `{"schedule_items", "arrival_time"}` for a collection field.
  """
  def handle_form_change(form_id, form_name, inputs, params) do
    List.wrap(inputs)
    |> Enum.reduce(params, &handle_input(form_id, form_name, &1, &2))
    |> Map.get(form_name)
  end

  # For nested form
  # input_id(nested_f, :field) is voyage-form_schedule_items_0_departure_time
  # input_name(nested_f, :field) is voyage[schedule_items][0][departure_time]

  # Example of params for nested input
  # %{
  #   "_csrf_token" => "CScfIydyFngRPCILQEpWdwFFFD4mBm5hBjpywGg6SvDsv3nFLrYoMUW8",
  #   "_target" => ["voyage", "schedule_items", "0", "departure_location"],
  #   "datepicker" => %{
  #     "arrival_time-0" => %{
  #       "alt" => "Mon Nov 08, 2021 18:08",
  #       "hour" => "18",
  #       "iso" => "2021-11-08T18:08:05Z",
  #       "minute" => "05"
  #     },
  #     "departure_time-0" => %{
  #       "alt" => "Sat Nov 06, 2021 18:08",
  #       "hour" => "18",
  #       "iso" => "2021-11-06T18:08:05Z",
  #       "minute" => "05"
  #     }
  #   },
  #   "voyage" => %{
  #     "schedule_items" => %{
  #       "0" => %{
  #         "arrival_location" => "USCHI",
  #         "arrival_time" => "2021-11-08T18:08:05Z",
  #         "departure_location" => "SEGOT",
  #         "departure_time" => "2021-11-06T18:08:05Z"
  #       }
  #     },
  #     "voyage_number" => ""
  #   }
  # }
  #
  #
  # We loop through the indices in the nested collection and process the corresponding
  # datepicker fields.
  defp handle_input(form_id, form_name, {collection, field}, params) do
    # The indices are the keys at ["voyage", "schedule_items"]
    indices = get_in(params, [form_name, collection]) |> Map.keys()

    Enum.reduce(indices, params, fn index, acc ->
      # `form_id` will be "voyage-form"
      # `form_name will be "voyage"
      # `path` will be ["schedule_items", "0", "arrival_time"]
      # `dp_path` will be ["dp-voyage", "schedule_items", "0", "arrival_time"]
      # `form_path` will be ["voyage", "schedule_items", "0", "arrival_time"]
      do_handle_input(form_id, form_name, [collection, index, field], acc)
    end)
  end

  # Example of params for single input
  # %{
  #   "_csrf_token" => "CScfIydyFngRPCILQEpWdwFFFD4mBm5hBjpywGg6SvDsv3nFLrYoMUW8",
  #   "_target" => ["voyage", "schedule_items", "0", "departure_location"],
  #   "datepicker" => %{
  #     "arrival_deadline" => %{
  #       "alt" => "Mon Nov 08, 2021 18:08",
  #       "hour" => "18",
  #       "iso" => "2021-11-08T18:08:05Z",
  #       "minute" => "05"
  #     }
  #   },
  #   "edit_destination" => %{
  #     "arrival_deadline" => "2021-11-08T18:08:05Z",
  #     "destination" => "SEGOT"
  #   }
  # }
  #
  defp handle_input(form_id, form_name, field, params) when is_binary(field) do
    # `form_id` will be "cargo-destination-form"
    # `form_name will be "edit_destination"
    # `path` will be ["arrival_deadline"]
    # `dp_path` will be ["dp-edit_destination", "arrival_deadline"]
    # `form_path` will be ["edit_destination", "arrival_deadline"]
    do_handle_input(form_id, form_name, [field], params)
  end

  defp do_handle_input(form_id, form_name, path, params) do
    dp_path = ["dp-#{form_name}" | path]
    dp_params = get_in(params, dp_path)

    if is_nil(dp_params) do
      Logger.error("No map at #{inspect(dp_path)}")
      params
    else
      iso_str = Map.get(dp_params, "iso")
      {:ok, current_date, _offset} = DateTime.from_iso8601(iso_str)

      selected_date =
        with {:ok, h, m} <- parse_time(dp_params),
             {:ok, t} <- Time.new(h, m, 0),
             {:ok, new_date} <- DateTime.to_date(current_date) |> DateTime.new(t) do
          # Reset datepicker component's :selected_date
          dp_id = Enum.join(["dp-#{form_id}" | path], "_")
          _ = send_update(__MODULE__, id: dp_id, selected_date: new_date)
          new_date
        else
          _ -> current_date
        end

      put_in(params, [form_name | path], selected_date)
    end
  end

  @doc """
  Compare the month and year of the given date to the `max_date`.
  `max_date` can be either false (in which case `:lt` is always returned),
  or a struct or map with `:month` and `:year` items.

  Returns :lt, :eq, or :gt.
  """
  def compare_month(_month_year, false), do: :lt

  def compare_month(%{year: y1, month: m1}, %{year: y2, month: m2}) do
    cond do
      y1 < y2 || (y1 == y2 && m1 < m2) -> :lt
      y1 == y2 && m1 == m2 -> :eq
      true -> :gt
    end
  end

  @impl true
  def mount(socket) do
    next_socket =
      socket
      |> assign(
        state: "closed",
        hour_options: @hour_options,
        minute_options: @minute_options
      )

    {:ok, next_socket}
  end

  @impl true
  def update(assigns, socket) do
    max_date =
      case Map.get(assigns, :max_date, false) do
        %Date{} = d -> d
        true -> DateTime.utc_now() |> DateTime.to_date()
        _ -> false
      end

    {unclamped_date, time} =
      case Map.get(assigns, :selected_date) do
        %DateTime{} = dt ->
          t = DateTime.to_time(dt)
          {dt, t}

        %Date{} = d ->
          {:ok, t} = Time.new(0, 0, 0)
          {:ok, dt} = DateTime.new(d, t)
          {dt, t}

        _ ->
          dt = DateTime.utc_now()
          t = DateTime.to_time(dt)
          {dt, t}
      end

    month_compare = compare_month(unclamped_date, max_date)

    selected_date =
      if month_compare == :lt || (month_compare == :eq && unclamped_date.day <= max_date.day) do
        unclamped_date
      else
        {:ok, max_dt} = DateTime.new(max_date, time)
        max_dt
      end

    hour = time.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minute = (div(time.minute, 5) * 5) |> Integer.to_string() |> String.pad_leading(2, "0")

    assigns =
      assigns
      |> Map.put(:max_date, max_date)
      |> Map.put(:selected_date, selected_date)
      |> Map.put(:selected_hour, hour)
      |> Map.put(:selected_minute, minute)
      |> set_visible_month_year()
      |> put_next_month_selectable(max_date)

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("datepicker-clicked", _, socket) do
    {:noreply, assign(socket, :state, toggle_state(socket.assigns.state))}
  end

  def handle_event("prev-clicked", _, socket) do
    previous_month = previous_month(socket.assigns.visible_month_year)

    assigns =
      Map.new()
      |> Map.put(:visible_month_year, %{previous_month | day: 1})
      |> put_next_month_selectable(socket.assigns.max_date)

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("next-clicked", _, socket) do
    max_date = socket.assigns.max_date
    this_month = socket.assigns.visible_month_year
    next_month = next_month(this_month)

    assigns =
      if next_month_selectable?(this_month, max_date) do
        Map.new()
        |> Map.put(:visible_month_year, %{next_month | day: 1})
        |> put_next_month_selectable(max_date)
      else
        Map.new()
        |> Map.put(:next_month_selectable, false)
      end

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("date-clicked", %{"date" => date}, socket) do
    {:ok, new_date} = Date.from_iso8601(date)
    current_time = DateTime.to_time(socket.assigns.selected_date)
    {:ok, selected_date} = DateTime.new(new_date, current_time)

    assigns =
      Map.new()
      |> Map.put(:selected_date, selected_date)

    {:noreply, assign(socket, assigns)}
  end

  ## Private functions

  defp parse_time(%{"hour" => hour, "minute" => minute}) do
    with {:ok, h} <- valid_hour(hour),
         {:ok, m} <- valid_minute(minute) do
      {:ok, h, m}
    else
      _ ->
        :error
    end
  end

  defp parse_time(_), do: :error

  defp set_visible_month_year(%{selected_date: %DateTime{year: year, month: month}} = assigns) do
    {:ok, first_day_of_month} = Date.new(year, month, 1)
    Map.put(assigns, :visible_month_year, first_day_of_month)
  end

  defp valid_hour(hour) when is_integer(hour) do
    if hour >= 0 && hour < 24 do
      {:ok, hour}
    else
      {:error, :hour_invalid}
    end
  end

  defp valid_hour(""), do: {:error, :hour_empty}

  defp valid_hour(hour) when is_binary(hour) do
    case Integer.parse(hour) do
      {h, ""} ->
        valid_hour(h)

      _ ->
        {:error, :hour_invalid}
    end
  end

  defp valid_minute(minute) when is_integer(minute) do
    if minute >= 0 && minute < 60 do
      {:ok, minute}
    else
      {:error, :minute_invalid}
    end
  end

  defp valid_minute(""), do: {:error, :minute_empty}

  defp valid_minute(minute) when is_binary(minute) do
    case Integer.parse(minute) do
      {m, ""} ->
        valid_minute(m)

      _ ->
        {:error, :minute_invalid}
    end
  end

  defp toggle_state("open"), do: "closed"
  defp toggle_state("closed"), do: "open"

  defp put_next_month_selectable(%{visible_month_year: d} = assigns, max_date) do
    Map.put(assigns, :next_month_selectable, next_month_selectable?(d, max_date))
  end

  defp previous_month(%Date{day: day} = date) do
    last_of_last = Date.add(date, -day)
    days_in_last = last_of_last.day
    days = max(day, days_in_last)
    Date.add(date, -days)
  end

  defp next_month(%Date{day: day} = date) do
    days_this_month = Date.days_in_month(date)
    first_of_next = Date.add(date, days_this_month - day + 1)
    days_next_month = Date.days_in_month(first_of_next)
    Date.add(first_of_next, min(day, days_next_month) - 1)
  end

  defp next_month_selectable?(month_year, max_date) do
    m_compare = compare_month(month_year, max_date)
    m_compare == :lt
  end
end

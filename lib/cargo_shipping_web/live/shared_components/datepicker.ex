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

  @impl true
  def mount(socket) do
    next_socket =
      socket
      |> assign(
        state: "closed",
        calendar_class: "calendar hidden",
        hour_options: @hour_options,
        minute_options: @minute_options
      )

    {:ok, next_socket}
  end

  @impl true
  def update(assigns, socket) do
    {assigns, target_name} = maybe_put_target_names(assigns, socket)
    {assigns, max_date} = maybe_put_max_date(assigns, socket)

    {selected_datetime, selected_time} =
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

    month_compare = compare_month(selected_datetime, max_date)

    datetime =
      if month_compare == :lt || (month_compare == :eq && selected_datetime.day <= max_date.day) do
        selected_datetime
      else
        {:ok, max_datetime} = DateTime.new(max_date, selected_time)
        max_datetime
      end

    day = DateTime.to_date(datetime).day

    hour =
      selected_time.hour
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    minute =
      (div(selected_time.minute + 2, 5) * 5)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    {push_event?, next_assigns} =
      assigns
      |> Map.merge(%{
        selected_date: datetime,
        selected_day: day,
        selected_hour: hour,
        selected_minute: minute
      })
      |> put_visible_month_year()
      |> put_next_month_selectable(max_date)
      |> Map.pop(:push_event, false)

    next_socket =
      if push_event? do
        value = to_string(datetime)
        Logger.debug("push set-value #{target_name} #{value}")

        push_event(socket, "lvinput:set-value", %{name: target_name, value: value})
      else
        socket
      end

    {:ok, assign(next_socket, next_assigns)}
  end

  @impl true
  def handle_event("datepicker-clicked", _, socket) do
    {:noreply, assign(socket, toggle_state(socket.assigns.state))}
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

  def handle_event("day-clicked", %{"day" => day_str}, socket) do
    day = String.to_integer(day_str)
    month_year = socket.assigns.visible_month_year
    new_date = %{month_year | day: day}
    current_time = DateTime.to_time(socket.assigns.selected_date)
    {:ok, new_date} = DateTime.new(new_date, current_time)

    # Reset datepicker component's :selected_date
    _ = send_update_with_push_event(socket.assigns.id, new_date)
    {:noreply, socket}
  end

  ## Utility functions

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

  ## Post processing

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
  def handle_form_change(form_id, form_name, %{"_target" => target_path} = params) do
    next_params =
      case target_path do
        ["_datepicker" | rest] ->
          # Changed datepicker [hour] or [minute] fields
          len = Enum.count(rest)
          path = Enum.take(rest, len - 1)
          handle_input_path(form_id, form_name, path, params)

        _ ->
          # Changed non-datepicker fields
          Logger.debug("handle_form_change target #{inspect(target_path)}")
          params
      end

    Map.get(next_params, form_name)
  end

  def handle_form_change(_form_id, form_name, params), do: Map.get(params, form_name)

  ## Private functions

  # Example of params for nested input
  # %{
  #   "_csrf_token" => "CScfIydyFngRPCILQEpWdwFFFD4mBm5hBjpywGg6SvDsv3nFLrYoMUW8",
  #   "_target" => ["voyage", "schedule_items", "0", "departure_location"],
  #   "datepicker" => %{
  #     "schedule_items" => %{
  #       "0" => %{
  #         "arrival_time" => %{
  #           "alt" => "Mon Nov 08, 2021 18:08",
  #           "hour" => "18",
  #           "minute" => "05"
  #         },
  #         "departure_time" => %{
  #           "alt" => "Sat Nov 06, 2021 18:08",
  #           "hour" => "18",
  #           "minute" => "05"
  #         }
  #       }
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

  # Example of params for single input
  # %{
  #   "_csrf_token" => "CScfIydyFngRPCILQEpWdwFFFD4mBm5hBjpywGg6SvDsv3nFLrYoMUW8",
  #   "_target" => ["voyage", "schedule_items", "0", "departure_location"],
  #   "_datepicker" => %{
  #     "arrival_deadline" => %{
  #       "alt" => "Mon Nov 08, 2021 18:08",
  #       "hour" => "18",
  #       "minute" => "05"
  #     }
  #   },
  #   "edit_destination" => %{
  #     "arrival_deadline" => "2021-11-08T18:08:05Z",
  #     "destination" => "SEGOT"
  #   }
  # }
  #

  defp handle_input_path(form_id, form_name, path, params) do
    Logger.debug("handle_input_path #{inspect(path)}")

    dp_id = Enum.join([form_id | path], "_") <> "_datepicker"
    form_path = [form_name | path]

    dp_params_path = ["_datepicker" | path]
    dp_params = get_in(params, dp_params_path)

    if is_nil(dp_params) do
      Logger.error("No map at #{inspect(dp_params_path)}")
      params
    else
      iso_str = get_in(params, form_path)

      if !is_binary(iso_str) do
        Logger.error("No date value at #{inspect(form_path)}")
        params
      else
        with {:ok, current_date, _offset} = DateTime.from_iso8601(iso_str),
             {:ok, h, m} <- parse_time(dp_params),
             {:ok, t} <- Time.new(h, m, 0),
             {:ok, new_date} <- DateTime.to_date(current_date) |> DateTime.new(t) do
          # Reset datepicker component's :selected_date
          _ = send_update_with_push_event(dp_id, new_date)
          put_in(params, [form_name | path], new_date)
        else
          error ->
            Logger.error("Failed to parse date and time #{inspect(error)}")

            params
        end
      end
    end
  end

  defp send_update_with_push_event(id, new_date) do
    send_update(__MODULE__, %{id: id, selected_date: new_date, push_event: true})
  end

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

  defp maybe_put_max_date(assigns, %{assigns: %{max_date: max_date}} = _socket),
    do: {assigns, max_date}

  defp maybe_put_max_date(%{max_date: max_date} = assigns, _) do
    max_date_value =
      case max_date do
        %Date{} = d -> d
        true -> DateTime.utc_now() |> DateTime.to_date()
        false -> false
      end

    {Map.put(assigns, :max_date, max_date_value), max_date_value}
  end

  defp maybe_put_max_date(assigns, _), do: {Map.put(assigns, :max_date, false), false}

  defp maybe_put_target_names(
         assigns,
         %{assigns: %{target_name: target_name, dp_target_name: _dp_target_name}} = _socket
       ) do
    {assigns, target_name}
  end

  defp maybe_put_target_names(%{target_name: target_name} = assigns, _) do
    dp_target_name = Regex.replace(~r/^[^[]+/, target_name, "_datepicker")
    {Map.put(assigns, :dp_target_name, dp_target_name), target_name}
  end

  defp put_visible_month_year(%{selected_date: %DateTime{year: year, month: month}} = assigns) do
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

  defp toggle_state("open") do
    %{state: "closed", calendar_class: "calendar hidden"}
  end

  defp toggle_state(_) do
    %{state: "open", calendar_class: "calendar"}
  end

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

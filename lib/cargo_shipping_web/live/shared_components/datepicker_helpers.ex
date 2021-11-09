defmodule CargoShippingWeb.SharedComponents.DatepickerHelpers do
  @moduledoc """
  View helpers for Datepicker
  """

  alias CargoShippingWeb.SharedComponents.Datepicker

  @month_names ~w(January February March April May June July August September October November December)

  def humanize_date(%DateTime{} = dt), do: Timex.format!(dt, "%a %b %d, %Y %H:%M", :strftime)
  def humanize_date(_), do: nil

  def full_month_name(%Date{} = date), do: Enum.at(@month_names, date.month - 1)

  def full_year(%Date{} = date), do: to_string(date.year)

  def blank_cells(%Date{day: 1} = date) do
    dow = Date.day_of_week(date)

    case dow do
      7 -> 0
      _ -> dow
    end
  end

  def selectable_cells(date, max_date) do
    case Datepicker.compare_month(date, max_date) do
      :lt -> Date.days_in_month(date)
      :eq -> max_date.day
      :gt -> 0
    end
  end

  def unselectable_cells(date, max_date) do
    case Datepicker.compare_month(date, max_date) do
      :lt -> 0
      _ -> Date.days_in_month(date)
    end
  end

  def selectable_cell_value(visible_month_year, i) do
    %{visible_month_year | day: i}
  end

  def selectable_cell_class(_i, nil), do: "day selectable"

  def selectable_cell_class(i, selected_day) do
    if i == selected_day do
      "day selectable selected"
    else
      "day selectable"
    end
  end

  def hour_selected(value, selected_hour) do
    {v, _} = Integer.parse(value)
    {h, _} = Integer.parse(selected_hour)

    v == h
  end

  def minute_selected(value, selected_minute) do
    {v, _} = Integer.parse(value)
    {m, _} = Integer.parse(selected_minute)

    abs(v - m) < 3
  end
end

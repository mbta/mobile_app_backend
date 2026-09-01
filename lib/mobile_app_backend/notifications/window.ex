defmodule MobileAppBackend.Notifications.Window do
  use MobileAppBackend.Schema
  import Ecto.Query

  alias MBTAV3API.Alert

  typed_schema "notification_subscription_windows" do
    belongs_to(:subscription, MobileAppBackend.Notifications.Subscription)

    field(:start_time, :time, null: false)
    field(:end_time, :time, null: false)
    field(:days_of_week, {:array, :integer}, null: false)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns `true` if the given window is open at the specified `DateTime`.
  The `DateTime` is converted to the "America/New_York" timezone for comparison.
  If the end time is earlier than the start time, the window is considered to go past midnight into the next calendar day.
  """
  @spec open?(t(), DateTime.t()) :: boolean()
  def open?(%__MODULE__{} = window, now) do
    now = DateTime.shift_zone!(now, "America/New_York")
    time = DateTime.to_time(now)
    day_of_week = Date.day_of_week(now)

    if overnight?(window) do
      (Time.compare(window.start_time, time) != :gt and day_of_week in window.days_of_week) or
        (Time.compare(time, window.end_time) != :gt and
           previous_day_of_week(day_of_week) in window.days_of_week)
    else
      Time.compare(window.start_time, time) != :gt and
        Time.compare(time, window.end_time) != :gt and
        day_of_week in window.days_of_week
    end
  end

  @doc """
  An Ecto dynamic expression equivalent to `time_open?/3`, for use in Ecto queries.
  `binding` is the name given to the windows join via `as:`.
  """
  @spec open_dynamic(atom(), DateTime.t()) :: Ecto.Query.dynamic_expr()
  def open_dynamic(binding, at) do
    now = DateTime.shift_zone!(at, "America/New_York")
    time = DateTime.to_time(now)
    day_of_week = Date.day_of_week(now)
    previous_day_of_week = previous_day_of_week(day_of_week)

    dynamic(
      [{^binding, w}],
      (w.start_time <= w.end_time and w.start_time <= ^time and ^time <= w.end_time and
         ^day_of_week in w.days_of_week) or
        (w.start_time > w.end_time and
           ((w.start_time <= ^time and ^day_of_week in w.days_of_week) or
              (^time <= w.end_time and ^previous_day_of_week in w.days_of_week)))
    )
  end

  @spec next_overlap([Alert.ActivePeriod.t()], [t()], DateTime.t()) :: DateTime.t() | nil
  def next_overlap(active_periods, windows, now)
      when is_list(active_periods)
      when is_list(windows) do
    active_periods
    |> Stream.flat_map(fn active_period -> Stream.map(windows, &{active_period, &1}) end)
    |> Stream.map(fn {active_period, window} ->
      next_overlap(active_period, window, now)
    end)
    |> Stream.reject(&is_nil/1)
    |> Enum.min(DateTime, fn -> nil end)
  end

  @spec next_overlap(Alert.ActivePeriod.t(), t(), DateTime.t()) :: DateTime.t() | nil
  def next_overlap(%Alert.ActivePeriod{} = active_period, %__MODULE__{} = window, now) do
    period_start = Enum.max([active_period.start, now], DateTime)
    period_days = days_between(period_start, active_period.end)
    overnight? = overnight?(window)
    window_end_date_offset = if overnight?, do: 1, else: 0

    # An overnight window whose day of week is the day before the period starts can still be open
    # in the early morning of the active period's start day
    period_days =
      if overnight?,
        do: Stream.concat([Date.add(DateTime.to_date(period_start), -1)], period_days),
        else: period_days

    period_open_days = Stream.filter(period_days, &(Date.day_of_week(&1) in window.days_of_week))

    Enum.find_value(period_open_days, fn date ->
      window_start = Util.DateTime.new_safe(date, window.start_time)

      window_end =
        Util.DateTime.new_safe(Date.add(date, window_end_date_offset), window.end_time)

      cond do
        DateTime.compare(window_end, period_start) == :lt ->
          nil

        not is_nil(active_period.end) and DateTime.compare(window_start, active_period.end) == :gt ->
          nil

        DateTime.compare(window_start, period_start) == :lt ->
          period_start

        true ->
          window_start
      end
    end)
  end

  # A window whose end time is in the calendar day after its selected day of the week
  defp overnight?(%__MODULE__{start_time: start_time, end_time: end_time}) do
    Time.compare(start_time, end_time) == :gt
  end

  defp previous_day_of_week(1), do: 7
  defp previous_day_of_week(day_of_week), do: day_of_week - 1

  defp days_between(start_datetime, end_datetime) do
    start_day = DateTime.to_date(start_datetime)

    end_day =
      if end_datetime do
        DateTime.to_date(end_datetime)
      else
        # window can’t be more than a week away
        Date.add(start_day, 7)
      end

    case Date.compare(start_day, end_day) do
      :lt -> Date.range(start_day, end_day)
      :eq -> [start_day]
      :gt -> []
    end
  end
end

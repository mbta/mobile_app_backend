defmodule MobileAppBackend.Notifications.Window do
  use MobileAppBackend.Schema

  alias MBTAV3API.Alert

  typed_schema "notification_subscription_windows" do
    belongs_to(:subscription, MobileAppBackend.Notifications.Subscription)

    field(:start_time, :time, null: false)
    field(:end_time, :time, null: false)
    field(:days_of_week, {:array, :integer}, null: false)

    timestamps(type: :utc_datetime)
  end

  def open?(%__MODULE__{} = window, now) do
    now = DateTime.shift_zone!(now, "America/New_York")
    time = DateTime.to_time(now)
    day_of_week = Date.day_of_week(now)

    Time.compare(window.start_time, time) != :gt and Time.compare(time, window.end_time) != :gt and
      day_of_week in window.days_of_week
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

    period_open_days = Stream.filter(period_days, &(Date.day_of_week(&1) in window.days_of_week))

    Enum.find_value(period_open_days, fn date ->
      window_start = DateTime.new!(date, window.start_time, "America/New_York")
      window_end = DateTime.new!(date, window.end_time, "America/New_York")

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

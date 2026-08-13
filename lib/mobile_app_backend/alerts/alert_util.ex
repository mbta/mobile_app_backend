defmodule MobileAppBackend.Alerts.AlertUtil do
  alias MBTAV3API.Alert
  alias MBTAV3API.Repository
  alias MBTAV3API.Schedule
  alias MBTAV3API.Trip

  require Logger

  # Fetch schedules for all trip IDs referenced in the alert's informed_entity list
  @spec fetch_schedules_for_alert(Alert.t(), DateTime.t()) ::
          {[Schedule.t()] | nil, %{String.t() => Trip.t()} | nil}
  def fetch_schedules_for_alert(alert, now) do
    trip_ids = trip_ids(alert)
    dates = relevant_service_dates(alert, now)

    case trip_ids do
      [] ->
        {nil, nil}

      trip_ids when not is_nil(dates) ->
        {_, schedules, trips} =
          Enum.reduce(dates, {trip_ids, [], %{}}, &reduce_trip_alert_schedules/2)

        {schedules, trips}

      _ ->
        {nil, nil}
    end
  end

  defp trip_ids(alert),
    do: alert.informed_entity |> Enum.map(& &1.trip) |> Enum.uniq() |> Enum.reject(&is_nil/1)

  defp reduce_trip_alert_schedules(date, {remaining_trip_ids, acc_schedules, acc_trips}) do
    case remaining_trip_ids do
      [] ->
        {[], acc_schedules, acc_trips}

      remaining_trip_ids ->
        case Repository.schedules(
               filter: [trip: remaining_trip_ids, date: date],
               include: [trip: :stops],
               sort: {:stop_sequence, :asc}
             ) do
          {:ok, %{data: date_schedules, included: %{trips: date_trips}}} ->
            {
              remaining_trip_ids -- (date_trips |> Map.keys()),
              acc_schedules ++ date_schedules,
              Map.merge(acc_trips, date_trips)
            }

          response ->
            Logger.error(
              "failed to fetch schedules for trip_ids #{inspect(remaining_trip_ids)} response=#{inspect(response)}"
            )

            {remaining_trip_ids, acc_schedules, acc_trips}
        end
    end
  end

  defp service_day_matches?(nil, _), do: false

  defp service_day_matches?(datetime, service_day) do
    Util.DateTime.datetime_to_gtfs(datetime) == service_day
  end

  defp date_range(nil), do: nil
  defp date_range({first, last}), do: Date.range(first, last)

  def relevant_service_dates(alert, now) do
    today = Util.DateTime.datetime_to_gtfs(now)
    tomorrow = Date.add(today, 1)

    current_period = Alert.current_period(alert, now)
    next_period = Alert.next_period(alert, now)

    # Since notifications are only sent for alerts happening today or tomorrow, we only consider these two days
    service_bounds =
      cond do
        not is_nil(current_period) ->
          if service_day_matches?(current_period.end, today),
            do: {today, today},
            else: {today, tomorrow}

        not is_nil(next_period) ->
          cond do
            service_day_matches?(next_period.end, today) -> {today, today}
            service_day_matches?(next_period.start, today) -> {today, tomorrow}
            service_day_matches?(next_period.start, tomorrow) -> {tomorrow, tomorrow}
            true -> nil
          end

        true ->
          nil
      end

    date_range(service_bounds)
  end
end

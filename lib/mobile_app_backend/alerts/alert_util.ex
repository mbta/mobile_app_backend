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
    trip_ids = Alert.trip_ids(alert)
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

  # Fetch trips for all trip IDs referenced in all alerts informed_entity lists
  @spec fetch_trips_for_alerts([Alert.t()], DateTime.t()) :: [Trip.t()]
  def fetch_trips_for_alerts(alerts, now) do
    trip_ids = Alert.trip_ids(alerts)

    case trip_ids do
      [] ->
        []

      trip_ids ->
        {_, trips} =
          Enum.reduce(
            date_range(today_and_tomorrow(now)),
            {trip_ids, []},
            &reduce_trip_alert_trips/2
          )

        trips
    end
  end

  defp reduce_trip_alert_schedules(date, {remaining_trip_ids, acc_schedules, acc_trips}) do
    case remaining_trip_ids do
      [] ->
        {[], acc_schedules, acc_trips}

      remaining_trip_ids ->
        case Repository.schedules(
               filter: [trip: remaining_trip_ids, date: date],
               include: [trip: :stops],
               sort: {:stop_sequence, :asc},
               fields: [stop: []]
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

  defp reduce_trip_alert_trips(date, {remaining_trip_ids, acc_trips}) do
    case remaining_trip_ids do
      [] ->
        {[], acc_trips}

      remaining_trip_ids ->
        case Repository.trips(
               [
                 filter: [id: remaining_trip_ids, date: date],
                 include: [:stops],
                 fields: [stop: []]
               ],
               cache_empty: true
             ) do
          {:ok, %{data: date_trips}} ->
            {
              remaining_trip_ids -- Enum.map(date_trips, & &1.id),
              acc_trips ++ date_trips
            }

          response ->
            Logger.error(
              "failed to fetch trips for trip_ids #{inspect(remaining_trip_ids)} response=#{inspect(response)}"
            )

            {remaining_trip_ids, acc_trips}
        end
    end
  end

  defp service_day_matches?(nil, _), do: false

  defp service_day_matches?(datetime, service_day) do
    Util.DateTime.datetime_to_gtfs(datetime) == service_day
  end

  defp date_range(nil), do: nil
  defp date_range({first, last}), do: Date.range(first, last)

  defp today_and_tomorrow(now) do
    today = Util.DateTime.datetime_to_gtfs(now)
    tomorrow = Date.add(today, 1)
    {today, tomorrow}
  end

  defp relevant_service_dates(alert, now) do
    {today, tomorrow} = today_and_tomorrow(now)

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

defmodule MobileAppBackendWeb.ScheduleController do
  use MobileAppBackendWeb, :controller
  require Logger
  alias MobileAppBackend.GlobalDataCache
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Repository

  def schedules(conn, %{"stop_ids" => stop_ids_concat, "date_time" => date_time_string} = params) do
    if stop_ids_concat == "" do
      json(conn, %{schedules: [], trips: %{}})
    else
      stop_ids = String.split(stop_ids_concat, ",")

      date_time = Util.parse_datetime!(date_time_string)
      service_date = Util.datetime_to_gtfs(date_time)

      filters = Enum.map(stop_ids, &get_filter(&1, service_date))

      parallel_timeout = String.to_integer(Map.get(params, "timeout", "5000"))

      data =
        case filters do
          [filter] -> fetch_schedules(filter, date_time)
          filters -> fetch_schedules_parallel(filters, date_time, parallel_timeout)
        end

      case data do
        :error ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "fetch_failed"})

        data ->
          json(conn, data)
      end
    end
  end

  def schedules(conn, %{"trip_id" => trip_id}) do
    {:ok, %{data: schedules}} =
      Repository.schedules(filter: [trip: trip_id], sort: {:stop_sequence, :asc})

    response =
      if schedules == [] do
        {:ok, %{included: %{trips: trips}}} =
          Repository.trips(
            filter: [id: trip_id],
            include: [route_pattern: [representative_trip: :stops]],
            fields: [stop: []]
          )

        case Map.values(trips) do
          [] -> %{type: :unknown}
          [%MBTAV3API.Trip{stop_ids: stop_ids}] -> %{type: :stop_ids, stop_ids: stop_ids}
        end
      else
        %{type: :schedules, schedules: schedules}
      end

    json(conn, response)
  end

  @spec get_filter(String.t(), Date.t()) :: [JsonApi.Params.filter_param()]
  defp get_filter(stop_id, service_date) do
    [stop: stop_id, date: service_date]
  end

  @spec fetch_schedules_parallel([[JsonApi.Params.filter_param()]], DateTime.t(), integer()) ::
          %{schedules: [MBTAV3API.Schedule.t()], trips: JsonApi.Object.trip_map()} | :error
  defp fetch_schedules_parallel(filters, date_time, timeout) do
    filters
    |> Task.async_stream(
      fn filter_params ->
        {filter_params, fetch_schedules(filter_params, date_time)}
      end,
      ordered: false,
      timeout: timeout
    )
    |> Enum.reduce_while(%{schedules: [], trips: %{}}, fn result, acc ->
      case result do
        {:ok, {_params, %{schedules: schedules, trips: trips}}} ->
          {:cont, %{schedules: acc.schedules ++ schedules, trips: Map.merge(acc.trips, trips)}}

        {_result_type, {params, _response}} ->
          Logger.warning(
            "#{__MODULE__} skipped returning schedules due to error. params=#{inspect(params)}"
          )

          {:halt, :error}
      end
    end)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("#{__MODULE__} fetch_schedules_parallel timeout timeout=#{timeout}")
      :error
  end

  @spec fetch_schedules([JsonApi.Params.filter_param()], DateTime.t()) ::
          %{schedules: [MBTAV3API.Schedule.t()], trips: JsonApi.Object.trip_map()}
          | :error
  defp fetch_schedules(filter, date_time) do
    case Repository.schedules(filter: filter, include: :trip) do
      {:ok, %{data: schedules, included: %{trips: trips}}} ->
        filter_past_schedules(schedules, trips, date_time)

      _ ->
        :error
    end
  end

  defp last_schedule_grouping(schedule, nil), do: {schedule.route_id, nil}
  defp last_schedule_grouping(schedule, trip), do: {schedule.route_id, trip.direction_id}

  @spec filter_past_schedules([MBTAV3API.Schedule.t()], JsonApi.Object.trip_map(), DateTime.t()) ::
          %{schedules: [MBTAV3API.Schedule.t()], trips: JsonApi.Object.trip_map()}
  defp filter_past_schedules(schedules, trips, date_time) do
    global_data = GlobalDataCache.get_data()

    last_schedule_ids =
      schedules
      |> Enum.group_by(&last_schedule_grouping(&1, Map.get(trips, &1.trip_id)))
      |> Enum.map(fn {_grouping, schedules} -> List.last(schedules) end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(& &1.id)

    relevant_schedules =
      Enum.filter(schedules, fn schedule ->
        global_data.routes[schedule.route_id].type in [:commuter_rail, :ferry] or
          schedule.id in last_schedule_ids or
          DateTime.compare(schedule.departure_time, DateTime.add(date_time, -1, :hour)) != :lt
      end)

    relevant_trips = Map.take(trips, Enum.map(relevant_schedules, & &1.trip_id))
    %{schedules: relevant_schedules, trips: relevant_trips}
  end
end

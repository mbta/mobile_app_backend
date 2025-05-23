defmodule MobileAppBackendWeb.ScheduleController do
  use MobileAppBackendWeb, :controller
  require Logger
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Repository

  def schedules(conn, %{"stop_ids" => stop_ids_concat, "date_time" => date_time} = params) do
    if stop_ids_concat == "" do
      json(conn, %{schedules: [], trips: %{}})
    else
      stop_ids = String.split(stop_ids_concat, ",")

      service_date = parse_service_date(date_time)

      filters = Enum.map(stop_ids, &get_filter(&1, service_date))

      parallel_timeout = String.to_integer(Map.get(params, "timeout", "5000"))

      data =
        case filters do
          [filter] -> fetch_schedules(filter)
          filters -> fetch_schedules_parallel(filters, parallel_timeout)
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

  @spec parse_service_date(String.t()) :: Date.t()
  defp parse_service_date(date_string) do
    date_string
    |> Util.parse_datetime!()
    |> Util.datetime_to_gtfs()
  end

  @spec get_filter(String.t(), Date.t()) :: [JsonApi.Params.filter_param()]
  defp get_filter(stop_id, service_date) do
    [stop: stop_id, date: service_date]
  end

  @spec fetch_schedules_parallel([[JsonApi.Params.filter_param()]], integer()) ::
          %{schedules: [MBTAV3API.Schedule.t()], trips: JsonApi.Object.trip_map()} | :error
  defp fetch_schedules_parallel(filters, timeout) do
    filters
    |> Task.async_stream(
      fn filter_params ->
        {filter_params, fetch_schedules(filter_params)}
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

  @spec fetch_schedules([JsonApi.Params.filter_param()]) ::
          %{schedules: [MBTAV3API.Schedule.t()], trips: JsonApi.Object.trip_map()}
          | :error
  defp fetch_schedules(filter) do
    case Repository.schedules(filter: filter, include: :trip) do
      {:ok, %{data: schedules, included: %{trips: trips}}} ->
        %{schedules: schedules, trips: trips}

      _ ->
        :error
    end
  end
end

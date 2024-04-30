defmodule MobileAppBackendWeb.ScheduleController do
  use MobileAppBackendWeb, :controller
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Repository

  def schedules(conn, %{"stop_ids" => stop_ids, "date_time" => date_time}) do
    {:ok, data} =
      get_filter(stop_ids, date_time)
      |> fetch_schedules()

    json(conn, data)
  end

  @spec get_filter(String.t(), String.t()) :: [JsonApi.Params.filter_param()]
  defp get_filter(stop_ids, date_time) do
    date_time = Util.parse_datetime!(date_time)
    {service_date, min_time} = Util.datetime_to_gtfs(date_time)
    [stop: stop_ids, date: service_date, min_time: min_time]
  end

  @spec fetch_schedules([JsonApi.Params.filter_param()]) ::
          {:ok, %{schedules: [MBTAV3API.Schedule.t()], trips: JsonApi.Object.trip_map()}}
          | {:error, term()}
  defp fetch_schedules(filter) do
    with {:ok, %{data: schedules, included: %{trips: trips}}} <-
           Repository.schedules(filter: filter, include: :trip, sort: {:departure_time, :asc}) do
      {:ok, %{schedules: schedules, trips: trips}}
    end
  end
end

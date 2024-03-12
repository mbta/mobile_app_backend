defmodule MobileAppBackendWeb.ScheduleController do
  use MobileAppBackendWeb, :controller
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Repository

  def schedule(conn, params) do
    filter = get_filter(params)
    data = fetch_schedules(filter)

    json(conn, data)
  end

  @spec get_filter(map()) :: [JsonApi.Params.filter_param()]
  defp get_filter(%{"stop_ids" => stop_ids, "time" => time}) do
    time = Util.parse_datetime!(time)
    {service_date, min_time} = Util.datetime_to_gtfs(time)
    [stop: stop_ids, date: service_date, min_time: min_time]
  end

  @spec fetch_schedules([JsonApi.Params.filter_param()]) :: %{
          schedules: [MBTAV3API.Schedule.t()],
          trips: JsonApi.Object.trip_map()
        }
  defp fetch_schedules(filter) do
    {:ok, %{data: schedules, included: %{trips: trips}}} =
      Repository.schedules(filter: filter, include: :trip, sort: {:departure_time, :asc})

    %{schedules: schedules, trips: trips}
  end
end

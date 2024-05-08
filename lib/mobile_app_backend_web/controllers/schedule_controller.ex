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

  def schedules(conn, %{"trip_id" => trip_id}) do
    {:ok, %{data: schedules}} =
      Repository.schedules(filter: [trip: trip_id], sort: {:stop_sequence, :asc})

    response =
      if schedules == [] do
        {:ok, %{data: [trip]}} = Repository.trips(filter: [id: trip_id])

        if is_nil(trip.route_pattern_id) do
          %{type: :unknown}
        else
          {:ok, %{included: %{trips: trips}}} =
            Repository.route_patterns(
              filter: [id: trip.route_pattern_id],
              include: [representative_trip: :stops],
              fields: [stop: []]
            )

          [representative_trip] = Map.values(trips)

          %{type: :stop_ids, stop_ids: representative_trip.stop_ids}
        end
      else
        %{type: :schedules, schedules: schedules}
      end

    json(conn, response)
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

defmodule MobileAppBackendWeb.NextScheduleController do
  require Logger
  use MobileAppBackendWeb, :controller
  alias MBTAV3API.Repository
  alias MBTAV3API.Service

  def next_schedule(conn, %{
        "route" => route_id,
        "stop" => stop_id,
        "direction" => direction_id,
        "date_time" => date_time
      }) do
    direction_id = String.to_integer(direction_id)

    service_date =
      date_time
      |> Util.DateTime.parse_datetime!()
      |> Util.DateTime.datetime_to_gtfs()

    # as an optimization, skip loading the services if there is a schedule tomorrow
    next_schedule =
      if first_schedule_tomorrow =
           first_schedule_on(Date.add(service_date, 1), route_id, stop_id, direction_id) do
        first_schedule_tomorrow
      else
        {:ok, %{data: services}} = Repository.services(filter: [route: route_id])

        next_schedule_from_services(
          services,
          service_date,
          route_id,
          stop_id,
          direction_id
        )
      end

    json(conn, %{"next_schedule" => next_schedule})
  end

  defp next_schedule_from_services(
         services,
         service_date,
         route_id,
         stop_id,
         direction_id
       ) do
    {time_in_us, first_schedule} =
      :timer.tc(fn ->
        next_service_dates = Service.next_active(services, service_date)

        Enum.find_value(next_service_dates, fn service_date ->
          first_schedule_on(service_date, route_id, stop_id, direction_id)
        end)
      end)

    Logger.info(
      "#{__MODULE__} next_schedule after API calls route=#{route_id} stop=#{stop_id} direction=#{direction_id} duration_ms=#{time_in_us / 1000}"
    )

    first_schedule
  end

  defp first_schedule_on(service_date, route, stop, direction) do
    {:ok, %{data: schedules}} =
      Repository.schedules(
        filter: [
          route: route,
          stop: stop,
          direction_id: direction,
          date: service_date
        ],
        page: [limit: 1],
        sort: {:time, :asc}
      )

    case schedules do
      [first_schedule] -> first_schedule
      _ -> nil
    end
  end
end

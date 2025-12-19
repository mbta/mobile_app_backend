defmodule MobileAppBackendWeb.NextScheduleControllerTest do
  use MobileAppBackendWeb.ConnCase
  use HttpStub.Case
  import Mox
  import MobileAppBackend.Factory
  import Test.Support.Helpers

  setup do
    verify_on_exit!()
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    :ok
  end

  test "finds the next schedule", %{conn: conn} do
    now = DateTime.from_unix!(1_765_209_600)
    today = DateTime.to_date(now)
    tomorrow = Date.add(today, 1)
    later_day = Date.add(today, 5)
    service = build(:service, added_dates: [later_day])
    schedule = build(:schedule)

    route = "CR-Foxboro"
    stop = "place-sstat"
    direction = 0

    RepositoryMock
    |> expect(:schedules, fn [
                               filter: [
                                 route: ^route,
                                 stop: ^stop,
                                 direction_id: ^direction,
                                 date: ^tomorrow
                               ],
                               page: [limit: 1],
                               sort: {:time, :asc}
                             ],
                             _opts ->
      ok_response([])
    end)
    |> expect(:services, fn [filter: [route: ^route]], _opts ->
      ok_response([service])
    end)
    |> expect(:schedules, fn [
                               filter: [
                                 route: ^route,
                                 stop: ^stop,
                                 direction_id: ^direction,
                                 date: ^later_day
                               ],
                               page: [limit: 1],
                               sort: {:time, :asc}
                             ],
                             _opts ->
      ok_response([schedule])
    end)

    conn =
      get(conn, "/api/schedules/next", %{
        route: "CR-Foxboro",
        stop: "place-sstat",
        direction: 0,
        date_time: DateTime.to_iso8601(now)
      })

    assert json_response(conn, :ok) == %{
             "next_schedule" => Jason.decode!(Jason.encode_to_iodata!(schedule))
           }
  end

  test "checks tomorrow before loading service to find later date", %{conn: conn} do
    now = DateTime.now!("America/New_York")
    today = Util.datetime_to_gtfs(now)
    tomorrow = Date.add(today, 1)
    schedule = build(:schedule)

    route = "CR-Foxboro"
    stop = "place-sstat"
    direction = 0

    RepositoryMock
    |> expect(:schedules, fn [
                               filter: [
                                 route: ^route,
                                 stop: ^stop,
                                 direction_id: ^direction,
                                 date: ^tomorrow
                               ],
                               page: [limit: 1],
                               sort: {:time, :asc}
                             ],
                             _opts ->
      ok_response([schedule])
    end)

    conn =
      get(conn, "/api/schedules/next", %{
        route: "CR-Foxboro",
        stop: "place-sstat",
        direction: 0,
        date_time: DateTime.to_iso8601(now)
      })

    assert json_response(conn, :ok) == %{
             "next_schedule" => Jason.decode!(Jason.encode_to_iodata!(schedule))
           }
  end

  test "returns null if no future service", %{conn: conn} do
    now = DateTime.now!("America/New_York")
    today = Util.datetime_to_gtfs(now)
    tomorrow = Date.add(today, 1)

    route = "CR-Foxboro"
    stop = "place-sstat"
    direction = 0

    RepositoryMock
    |> expect(:schedules, fn [
                               filter: [
                                 route: ^route,
                                 stop: ^stop,
                                 direction_id: ^direction,
                                 date: ^tomorrow
                               ],
                               page: [limit: 1],
                               sort: {:time, :asc}
                             ],
                             _opts ->
      ok_response([])
    end)
    |> expect(:services, fn [filter: [route: ^route]], _opts ->
      ok_response([])
    end)

    conn =
      get(conn, "/api/schedules/next", %{
        route: "CR-Foxboro",
        stop: "place-sstat",
        direction: 0,
        date_time: DateTime.to_iso8601(now)
      })

    assert json_response(conn, :ok) == %{"next_schedule" => nil}
  end
end

defmodule MobileAppBackendWeb.ScheduleControllerTest do
  use MobileAppBackendWeb.ConnCase
  use HttpStub.Case
  import ExUnit.CaptureLog
  import Mox
  import MobileAppBackend.Factory
  import Test.Support.Helpers
  import Test.Support.Sigils

  setup do
    verify_on_exit!()
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    MobileAppBackend.Search.Algolia.Cache.delete_all()
    :ok
  end

  test "returns schedules", %{conn: conn} do
    s1 =
      %MBTAV3API.Schedule{
        id: "schedule-60565179-70159-90",
        arrival_time: ~B[2024-03-13 01:07:00],
        departure_time: ~B[2024-03-13 01:07:00],
        drop_off_type: :regular,
        pick_up_type: :regular,
        stop_sequence: 90,
        route_id: "Green-B",
        stop_id: "70159",
        trip_id: "60565179"
      }

    s2 = %MBTAV3API.Schedule{
      id: "schedule-60565145-70158-590",
      arrival_time: "2024-03-13T01:15:00-04:00",
      departure_time: "2024-03-13T01:15:00-04:00",
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 590,
      route_id: "Green-C",
      stop_id: "70158",
      trip_id: "60565145"
    }

    t1 = build(:trip, id: s1.trip_id)
    t2 = build(:trip, id: s2.trip_id)

    RepositoryMock
    |> expect(:schedules, fn params, _opts ->
      assert [
               filter: [
                 stop: "place-boyls",
                 date: ~D[2024-03-12]
               ],
               include: :trip
             ] = params

      ok_response([s1, s2], [t1, t2])
    end)

    conn =
      get(conn, "/api/schedules", %{
        stop_ids: "place-boyls",
        date_time: "2024-03-13T01:06:30-04:00"
      })

    assert %{
             "schedules" => [
               %{
                 "arrival_time" => "2024-03-13T01:07:00-04:00",
                 "departure_time" => "2024-03-13T01:07:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565179-70159-90",
                 "pick_up_type" => "regular",
                 "route_id" => "Green-B",
                 "stop_id" => "70159",
                 "stop_sequence" => 90,
                 "trip_id" => "60565179"
               },
               %{
                 "arrival_time" => "2024-03-13T01:15:00-04:00",
                 "departure_time" => "2024-03-13T01:15:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565145-70158-590",
                 "pick_up_type" => "regular",
                 "route_id" => "Green-C",
                 "stop_id" => "70158",
                 "stop_sequence" => 590,
                 "trip_id" => "60565145"
               }
             ],
             "trips" => %{
               "60565145" => %{},
               "60565179" => %{}
             }
           } = json_response(conn, 200)
  end

  test "returns schedules for multiple stops", %{conn: conn} do
    s1 =
      %MBTAV3API.Schedule{
        id: "schedule-60565179-70159-90",
        arrival_time: ~B[2024-03-13 01:07:00],
        departure_time: ~B[2024-03-13 01:07:00],
        drop_off_type: :regular,
        pick_up_type: :regular,
        stop_sequence: 90,
        route_id: "Green-B",
        stop_id: "70159",
        trip_id: "60565179"
      }

    s2 = %MBTAV3API.Schedule{
      id: "schedule-60565145-70158-590",
      arrival_time: "2024-03-13T01:15:00-04:00",
      departure_time: "2024-03-13T01:15:00-04:00",
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 590,
      route_id: "Green-C",
      stop_id: "70158",
      trip_id: "60565145"
    }

    t1 = build(:trip, id: s1.trip_id)
    t2 = build(:trip, id: s2.trip_id)

    RepositoryMock
    |> expect(:schedules, fn [
                               filter: [
                                 stop: "place-boyls",
                                 date: ~D[2024-03-12]
                               ],
                               include: :trip
                             ],
                             _opts ->
      ok_response([s1], [t1])
    end)
    |> expect(:schedules, fn [
                               filter: [
                                 stop: "place-pktrm",
                                 date: ~D[2024-03-12]
                               ],
                               include: :trip
                             ],
                             _opts ->
      ok_response([s2], [t2])
    end)

    conn =
      get(conn, "/api/schedules", %{
        stop_ids: "place-boyls,place-pktrm",
        date_time: "2024-03-13T01:06:30-04:00"
      })

    assert %{
             "schedules" => [
               %{
                 "arrival_time" => "2024-03-13T01:07:00-04:00",
                 "departure_time" => "2024-03-13T01:07:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565179-70159-90",
                 "pick_up_type" => "regular",
                 "route_id" => "Green-B",
                 "stop_id" => "70159",
                 "stop_sequence" => 90,
                 "trip_id" => "60565179"
               },
               %{
                 "arrival_time" => "2024-03-13T01:15:00-04:00",
                 "departure_time" => "2024-03-13T01:15:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565145-70158-590",
                 "pick_up_type" => "regular",
                 "route_id" => "Green-C",
                 "stop_id" => "70158",
                 "stop_sequence" => 590,
                 "trip_id" => "60565145"
               }
             ],
             "trips" => %{
               "60565145" => %{},
               "60565179" => %{}
             }
           } = json_response(conn, 200)
  end

  @tag :capture_log
  test "when any stop fetch errors, then returns error", %{conn: conn} do
    s1 =
      %MBTAV3API.Schedule{
        id: "schedule-60565179-70159-90",
        arrival_time: ~B[2024-03-13 01:07:00],
        departure_time: ~B[2024-03-13 01:07:00],
        drop_off_type: :regular,
        pick_up_type: :regular,
        stop_sequence: 90,
        route_id: "Green-B",
        stop_id: "70159",
        trip_id: "60565179"
      }

    t1 = build(:trip, id: s1.trip_id)

    RepositoryMock
    |> expect(:schedules, fn params, _opts ->
      assert [
               filter: [
                 stop: "place-boyls",
                 date: ~D[2024-03-12]
               ],
               include: :trip
             ] = params

      ok_response([s1], [t1])
    end)
    |> expect(:schedules, fn params, _opts ->
      assert [
               filter: [
                 stop: "place-pktrm",
                 date: ~D[2024-03-12]
               ],
               include: :trip
             ] = params

      {:error, :some_error_message}
    end)

    {conn, log} =
      with_log([level: :warning], fn ->
        get(conn, "/api/schedules", %{
          stop_ids: "place-boyls,place-pktrm",
          date_time: "2024-03-13T01:06:30-04:00"
        })
      end)

    assert %{"error" => "fetch_failed"} = json_response(conn, 500)

    assert log =~ "skipped returning schedules due to error"
  end

  @tag :capture_log
  test "when stop fetch times out, then cleanly returns error", %{conn: conn} do
    RepositoryMock
    |> expect(:schedules, 2, fn _params, _opts ->
      Process.sleep(200)
    end)

    {conn, log} =
      with_log([level: :warning], fn ->
        get(conn, "/api/schedules", %{
          stop_ids: "place-boyls,place-pktrm",
          date_time: "2024-03-13T01:06:30-04:00",
          timeout: 100
        })
      end)

    assert %{"error" => "fetch_failed"} = json_response(conn, 500)

    assert log =~ "fetch_schedules_parallel timeout"
  end

  test "gracefully handles empty stops", %{conn: conn} do
    conn = get(conn, "/api/schedules", %{stop_ids: "", date_time: "2024-10-28T15:29:06-04:00"})
    assert json_response(conn, 200) == %{"schedules" => [], "trips" => %{}}
  end

  test "finds individual trip schedules if available", %{conn: conn} do
    trip = %MBTAV3API.Trip{
      id: "61723264",
      direction_id: 1,
      headsign: "Ashmont",
      route_pattern_id: "Mattapan-_-1",
      shape_id: "899_0008",
      stop_ids: nil
    }

    trip_id = trip.id

    s1 = %MBTAV3API.Schedule{
      id: "schedule-61723264-70276-1",
      arrival_time: nil,
      departure_time: ~B[2024-05-07 12:30:00],
      drop_off_type: :unavailable,
      pick_up_type: :regular,
      stop_sequence: 1,
      route_id: "Mattapan",
      stop_id: "70276",
      trip_id: trip_id
    }

    s2 = %MBTAV3API.Schedule{
      id: "schedule-61723264-70274-2",
      arrival_time: ~B[2024-05-07 12:31:00],
      departure_time: ~B[2024-05-07 12:31:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 2,
      route_id: "Mattapan",
      stop_id: "70274",
      trip_id: trip_id
    }

    RepositoryMock
    |> expect(:schedules, fn params, _opts ->
      assert [
               filter: [trip: ^trip_id],
               sort: {:stop_sequence, :asc}
             ] = params

      ok_response([s1, s2])
    end)

    conn =
      get(conn, "/api/schedules", %{trip_id: trip_id})

    assert %{
             "type" => "schedules",
             "schedules" => [
               %{
                 "arrival_time" => nil,
                 "departure_time" => "2024-05-07T12:30:00-04:00",
                 "drop_off_type" => "unavailable",
                 "id" => "schedule-61723264-70276-1",
                 "pick_up_type" => "regular",
                 "route_id" => "Mattapan",
                 "stop_id" => "70276",
                 "stop_sequence" => 1,
                 "trip_id" => "61723264"
               },
               %{
                 "arrival_time" => "2024-05-07T12:31:00-04:00",
                 "departure_time" => "2024-05-07T12:31:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-61723264-70274-2",
                 "pick_up_type" => "regular",
                 "route_id" => "Mattapan",
                 "stop_id" => "70274",
                 "stop_sequence" => 2,
                 "trip_id" => "61723264"
               }
             ]
           } = json_response(conn, 200)
  end

  test "falls back to route pattern stop_ids for added trips", %{conn: conn} do
    added_trip = %MBTAV3API.Trip{
      id: "ADDED-1591579641",
      direction_id: 0,
      headsign: "Mattapan",
      route_pattern_id: "Mattapan-_-0",
      shape_id: "canonical-899_0005",
      stop_ids: nil
    }

    added_trip_id = added_trip.id

    route_pattern = %MBTAV3API.RoutePattern{
      id: "Mattapan-_-0",
      canonical: true,
      direction_id: 0,
      name: "Ashmont - Mattapan",
      sort_order: 100_110_000,
      typicality: :typical,
      representative_trip_id: "canonical-Mattapan-C1-0",
      route_id: "Mattapan"
    }

    canonical_trip = %MBTAV3API.Trip{
      id: "canonical-Mattapan-C1-0",
      direction_id: 0,
      headsign: "Mattapan",
      route_pattern_id: "Mattapan-_-0",
      shape_id: "canonical-899_0005",
      stop_ids: ["70261", "70263", "70265", "70267", "70269", "70271", "70273", "70275"]
    }

    RepositoryMock
    |> expect(:schedules, fn [filter: [trip: ^added_trip_id], sort: _], _ -> ok_response([]) end)
    |> expect(:trips, fn [filter: [id: ^added_trip_id], include: _, fields: _], _ ->
      ok_response([added_trip], [route_pattern, canonical_trip])
    end)

    conn = get(conn, "/api/schedules", %{trip_id: added_trip.id})

    assert %{
             "type" => "stop_ids",
             "stop_ids" => [
               "70261",
               "70263",
               "70265",
               "70267",
               "70269",
               "70271",
               "70273",
               "70275"
             ]
           } = json_response(conn, 200)
  end

  test "does not crash if added trip has no route pattern", %{conn: conn} do
    added_trip = %MBTAV3API.Trip{
      id: "ADDED-1591579641",
      direction_id: 0,
      headsign: "Mattapan",
      route_pattern_id: nil,
      shape_id: "canonical-899_0005",
      stop_ids: nil
    }

    RepositoryMock
    |> expect(:schedules, fn [filter: [trip: _], sort: _], _ -> ok_response([]) end)
    |> expect(:trips, fn [filter: [id: _], include: _, fields: _], _ ->
      ok_response([added_trip])
    end)

    conn = get(conn, "/api/schedules", %{trip_id: added_trip.id})

    assert %{"type" => "unknown"} = json_response(conn, 200)
  end
end

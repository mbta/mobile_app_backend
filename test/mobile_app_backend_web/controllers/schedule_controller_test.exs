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

  test "filters schedules in the past", %{conn: conn} do
    s1 =
      %MBTAV3API.Schedule{
        id: "schedule-60565179-70159-90",
        arrival_time: ~B[2024-03-13 08:07:00],
        departure_time: ~B[2024-03-13 08:07:00],
        drop_off_type: :regular,
        pick_up_type: :regular,
        stop_sequence: 90,
        route_id: "Green-C",
        stop_id: "70158",
        trip_id: "60565179"
      }

    s2 = %MBTAV3API.Schedule{
      id: "schedule-60565145-70158-90",
      arrival_time: ~B[2024-03-13 08:15:00],
      departure_time: ~B[2024-03-13 08:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 90,
      route_id: "Green-C",
      stop_id: "70158",
      trip_id: "60565145"
    }

    s3 = %MBTAV3API.Schedule{
      id: "schedule-60565146-70158-90",
      arrival_time: ~B[2024-03-13 10:15:00],
      departure_time: ~B[2024-03-13 10:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 90,
      route_id: "Green-C",
      stop_id: "70158",
      trip_id: "60565146"
    }

    s4 = %MBTAV3API.Schedule{
      id: "schedule-60565147-70158-90",
      arrival_time: ~B[2024-03-13 11:15:00],
      departure_time: ~B[2024-03-13 11:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 90,
      route_id: "Green-C",
      stop_id: "70158",
      trip_id: "60565147"
    }

    t1 = build(:trip, id: s1.trip_id)
    t2 = build(:trip, id: s2.trip_id)
    t3 = build(:trip, id: s3.trip_id)
    t4 = build(:trip, id: s4.trip_id)

    RepositoryMock
    |> expect(:schedules, fn params, _opts ->
      assert [
               filter: [
                 stop: "place-boyls",
                 date: ~D[2024-03-13]
               ],
               include: :trip
             ] = params

      ok_response([s1, s2, s3, s4], [t1, t2, t3, t4])
    end)

    conn =
      get(conn, "/api/schedules", %{
        stop_ids: "place-boyls",
        date_time: "2024-03-13T11:00:30-04:00"
      })

    assert %{
             "schedules" => [
               %{
                 "arrival_time" => "2024-03-13T10:15:00-04:00",
                 "departure_time" => "2024-03-13T10:15:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565146-70158-90",
                 "pick_up_type" => "regular",
                 "route_id" => "Green-C",
                 "stop_id" => "70158",
                 "stop_sequence" => 90,
                 "trip_id" => "60565146"
               },
               %{
                 "arrival_time" => "2024-03-13T11:15:00-04:00",
                 "departure_time" => "2024-03-13T11:15:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565147-70158-90",
                 "pick_up_type" => "regular",
                 "route_id" => "Green-C",
                 "stop_id" => "70158",
                 "stop_sequence" => 90,
                 "trip_id" => "60565147"
               }
             ],
             "trips" => %{
               "60565146" => %{},
               "60565147" => %{}
             }
           } = json_response(conn, 200)
  end

  test "does not filter ferry or cr schedules in the past", %{conn: conn} do
    s1 =
      %MBTAV3API.Schedule{
        id: "schedule-1-cr-stop-0",
        arrival_time: ~B[2024-03-13 08:07:00],
        departure_time: ~B[2024-03-13 08:07:00],
        drop_off_type: :regular,
        pick_up_type: :regular,
        stop_sequence: 0,
        route_id: "CR-NewBedford",
        stop_id: "cr-stop",
        trip_id: "1"
      }

    s2 = %MBTAV3API.Schedule{
      id: "schedule-2-cr-stop-0",
      arrival_time: ~B[2024-03-13 08:15:00],
      departure_time: ~B[2024-03-13 08:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "CR-NewBedford",
      stop_id: "cr-stop",
      trip_id: "2"
    }

    s3 = %MBTAV3API.Schedule{
      id: "schedule-3-ferry-stop-0",
      arrival_time: ~B[2024-03-13 08:15:00],
      departure_time: ~B[2024-03-13 08:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "Boat-F4",
      stop_id: "ferry-stop",
      trip_id: "3"
    }

    s4 = %MBTAV3API.Schedule{
      id: "schedule-4-ferry-stop-0",
      arrival_time: ~B[2024-03-13 08:30:00],
      departure_time: ~B[2024-03-13 08:30:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "Boat-F4",
      stop_id: "ferry-stop",
      trip_id: "4"
    }

    t1 = build(:trip, id: s1.trip_id)
    t2 = build(:trip, id: s2.trip_id)
    t3 = build(:trip, id: s3.trip_id)
    t4 = build(:trip, id: s4.trip_id)

    RepositoryMock
    |> expect(:schedules, 2, fn params, _opts ->
      case params do
        [
          filter: [
            stop: "cr-stop",
            date: ~D[2024-03-13]
          ],
          include: :trip
        ] ->
          ok_response([s1, s2], [t1, t2])

        [
          filter: [
            stop: "ferry-stop",
            date: ~D[2024-03-13]
          ],
          include: :trip
        ] ->
          ok_response([s3, s4], [t3, t4])

        _ ->
          flunk("unexpected params: #{inspect(params)}")
      end
    end)

    conn =
      get(conn, "/api/schedules", %{
        stop_ids: "cr-stop,ferry-stop",
        date_time: "2024-03-13T11:00:30-04:00"
      })

    assert %{
             "schedules" => [
               %{
                 "id" => "schedule-1-cr-stop-0",
                 "arrival_time" => "2024-03-13T08:07:00-04:00",
                 "departure_time" => "2024-03-13T08:07:00-04:00",
                 "drop_off_type" => "regular",
                 "pick_up_type" => "regular",
                 "stop_sequence" => 0,
                 "route_id" => "CR-NewBedford",
                 "stop_id" => "cr-stop",
                 "trip_id" => "1"
               },
               %{
                 "id" => "schedule-2-cr-stop-0",
                 "arrival_time" => "2024-03-13T08:15:00-04:00",
                 "departure_time" => "2024-03-13T08:15:00-04:00",
                 "drop_off_type" => "regular",
                 "pick_up_type" => "regular",
                 "stop_sequence" => 0,
                 "route_id" => "CR-NewBedford",
                 "stop_id" => "cr-stop",
                 "trip_id" => "2"
               },
               %{
                 "id" => "schedule-3-ferry-stop-0",
                 "arrival_time" => "2024-03-13T08:15:00-04:00",
                 "departure_time" => "2024-03-13T08:15:00-04:00",
                 "drop_off_type" => "regular",
                 "pick_up_type" => "regular",
                 "stop_sequence" => 0,
                 "route_id" => "Boat-F4",
                 "stop_id" => "ferry-stop",
                 "trip_id" => "3"
               },
               %{
                 "id" => "schedule-4-ferry-stop-0",
                 "arrival_time" => "2024-03-13T08:30:00-04:00",
                 "departure_time" => "2024-03-13T08:30:00-04:00",
                 "drop_off_type" => "regular",
                 "pick_up_type" => "regular",
                 "stop_sequence" => 0,
                 "route_id" => "Boat-F4",
                 "stop_id" => "ferry-stop",
                 "trip_id" => "4"
               }
             ],
             "trips" => %{
               "1" => %{},
               "2" => %{},
               "3" => %{},
               "4" => %{}
             }
           } = json_response(conn, 200)
  end

  test "does not filter the final trip for every unique route and direction combination", %{
    conn: conn
  } do
    s1 =
      %MBTAV3API.Schedule{
        id: "schedule-1-1259-0",
        arrival_time: ~B[2024-03-14 00:07:00],
        departure_time: ~B[2024-03-14 00:07:00],
        drop_off_type: :regular,
        pick_up_type: :regular,
        stop_sequence: 0,
        route_id: "66",
        stop_id: "1259",
        trip_id: "1"
      }

    s2 = %MBTAV3API.Schedule{
      id: "schedule-2-1259-0",
      arrival_time: ~B[2024-03-14 00:15:00],
      departure_time: ~B[2024-03-14 00:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "66",
      stop_id: "1259",
      trip_id: "2"
    }

    s3 = %MBTAV3API.Schedule{
      id: "schedule-3-1259-0",
      arrival_time: ~B[2024-03-14 00:15:00],
      departure_time: ~B[2024-03-14 00:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "66",
      stop_id: "1259",
      trip_id: "3"
    }

    s4 = %MBTAV3API.Schedule{
      id: "schedule-4-1259-0",
      arrival_time: ~B[2024-03-14 00:30:00],
      departure_time: ~B[2024-03-14 00:30:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "66",
      stop_id: "1259",
      trip_id: "4"
    }

    s5 = %MBTAV3API.Schedule{
      id: "schedule-5-1259-0",
      arrival_time: ~B[2024-03-14 00:15:00],
      departure_time: ~B[2024-03-14 00:15:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "44",
      stop_id: "1259",
      trip_id: "5"
    }

    s6 = %MBTAV3API.Schedule{
      id: "schedule-6-1259-0",
      arrival_time: ~B[2024-03-14 00:30:00],
      departure_time: ~B[2024-03-14 00:30:00],
      drop_off_type: :regular,
      pick_up_type: :regular,
      stop_sequence: 0,
      route_id: "44",
      stop_id: "1259",
      trip_id: "6"
    }

    t1 = build(:trip, id: s1.trip_id, direction_id: 0)
    t2 = build(:trip, id: s2.trip_id, direction_id: 0)
    t3 = build(:trip, id: s3.trip_id, direction_id: 1)
    t4 = build(:trip, id: s4.trip_id, direction_id: 1)
    t5 = build(:trip, id: s5.trip_id, direction_id: 0)
    t6 = build(:trip, id: s6.trip_id, direction_id: 0)

    RepositoryMock
    |> expect(:schedules, fn params, _opts ->
      assert [
               filter: [
                 stop: "1259",
                 date: ~D[2024-03-13]
               ],
               include: :trip
             ] = params

      ok_response([s1, s2, s3, s4, s5, s6], [t1, t2, t3, t4, t5, t6])
    end)

    conn =
      get(conn, "/api/schedules", %{
        stop_ids: "1259",
        date_time: "2024-03-14T02:31:30-04:00"
      })

    assert %{
             "schedules" => [
               %{
                 "id" => "schedule-2-1259-0",
                 "arrival_time" => "2024-03-14T00:15:00-04:00",
                 "departure_time" => "2024-03-14T00:15:00-04:00",
                 "drop_off_type" => "regular",
                 "pick_up_type" => "regular",
                 "stop_sequence" => 0,
                 "route_id" => "66",
                 "stop_id" => "1259",
                 "trip_id" => "2"
               },
               %{
                 "id" => "schedule-4-1259-0",
                 "arrival_time" => "2024-03-14T00:30:00-04:00",
                 "departure_time" => "2024-03-14T00:30:00-04:00",
                 "drop_off_type" => "regular",
                 "pick_up_type" => "regular",
                 "stop_sequence" => 0,
                 "route_id" => "66",
                 "stop_id" => "1259",
                 "trip_id" => "4"
               },
               %{
                 "id" => "schedule-6-1259-0",
                 "arrival_time" => "2024-03-14T00:30:00-04:00",
                 "departure_time" => "2024-03-14T00:30:00-04:00",
                 "drop_off_type" => "regular",
                 "pick_up_type" => "regular",
                 "stop_sequence" => 0,
                 "route_id" => "44",
                 "stop_id" => "1259",
                 "trip_id" => "6"
               }
             ],
             "trips" => %{
               "2" => %{},
               "4" => %{},
               "6" => %{}
             }
           } = json_response(conn, 200)
  end
end

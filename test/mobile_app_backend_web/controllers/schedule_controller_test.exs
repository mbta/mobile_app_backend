defmodule MobileAppBackendWeb.ScheduleControllerTest do
  use MobileAppBackendWeb.ConnCase
  use HttpStub.Case
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
                 date: ~D[2024-03-12],
                 min_time: "25:06"
               ],
               include: :trip,
               sort: {:departure_time, :asc}
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
end

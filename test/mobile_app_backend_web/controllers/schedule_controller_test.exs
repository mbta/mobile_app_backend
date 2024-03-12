defmodule MobileAppBackendWeb.ScheduleControllerTest do
  use MobileAppBackendWeb.ConnCase
  use HttpStub.Case

  test "returns schedules", %{conn: conn} do
    conn =
      get(conn, "/api/schedule", %{stop_ids: "place-boyls", time: "2024-03-13T01:06:30-04:00"})

    assert %{
             "schedules" => [
               %{
                 "arrival_time" => "2024-03-13T01:07:00-04:00",
                 "departure_time" => "2024-03-13T01:07:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565179-70159-90",
                 "pick_up_type" => "regular",
                 "stop_id" => "70159",
                 "trip_id" => "60565179"
               },
               %{
                 "arrival_time" => "2024-03-13T01:15:00-04:00",
                 "departure_time" => "2024-03-13T01:15:00-04:00",
                 "drop_off_type" => "regular",
                 "id" => "schedule-60565145-70158-590",
                 "pick_up_type" => "regular",
                 "stop_id" => "70158",
                 "trip_id" => "60565145"
               }
             ],
             "trips" => %{
               "60565145" => %{
                 "headsign" => "Medford/Tufts",
                 "id" => "60565145",
                 "route_pattern_id" => "Green-E-886-1",
                 "shape_id" => "8000015",
                 "stop_ids" => nil
               },
               "60565179" => %{
                 "headsign" => "Riverside",
                 "id" => "60565179",
                 "route_pattern_id" => "Green-D-855-0",
                 "shape_id" => "8000008",
                 "stop_ids" => nil
               }
             }
           } = json_response(conn, 200)
  end
end

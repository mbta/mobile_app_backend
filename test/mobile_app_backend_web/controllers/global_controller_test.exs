defmodule MobileAppBackendWeb.GlobalControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase

  describe "GET /api/global" do
    test "retrieves all stop and route info from the V3 API", %{conn: conn} do
      conn = get(conn, "/api/global")
      stop_response = json_response(conn, 200)

      assert %{
               "stops" => stops,
               "route_patterns" => route_patterns,
               "pattern_ids_by_stop" => pattern_ids,
               "routes" => routes
             } = stop_response

      assert length(stops) == 8015

      park_st_station = Enum.find(stops, &(Map.get(&1, "id") == "place-pktrm"))

      assert %{
               "id" => "place-pktrm",
               "name" => "Park Street",
               "location_type" => "station",
               "latitude" => 42.356395,
               "longitude" => -71.062424
             } = park_st_station

      park_st_rl_platform = Enum.find(stops, &(Map.get(&1, "id") == "70076"))

      assert %{
               "id" => "70076",
               "name" => "Park Street",
               "location_type" => "stop",
               "parent_station" => ^park_st_station
             } = park_st_rl_platform

      park_st_rl_patterns = Map.get(pattern_ids, Map.get(park_st_rl_platform, "id"))

      assert [
               "Red-3-1",
               "Red-1-1",
               "Red-C-1",
               "Red-R-1",
               "Red-C-1_70076_70068_0",
               "Red-R-1_70076_70068_0"
             ] = park_st_rl_patterns

      red_line_pattern = Map.get(route_patterns, "Red-1-1")

      assert %{
               "direction_id" => 1,
               "id" => "Red-1-1",
               "name" => "Ashmont - Alewife",
               "route" => %{"type" => "route", "id" => "Red"},
               "sort_order" => 100_101_001
             } = red_line_pattern

      assert %{
               "Red" => %{
                 "color" => "DA291C",
                 "direction_destinations" => ["Ashmont/Braintree", "Alewife"],
                 "direction_names" => ["South", "North"],
                 "id" => "Red",
                 "long_name" => "Red Line",
                 "type" => "heavy_rail"
               }
             } = routes
    end
  end
end

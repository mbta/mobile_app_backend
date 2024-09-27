defmodule MobileAppBackendWeb.GlobalControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers

  describe "GET /api/global" do
    setup do
      verify_on_exit!()

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.GlobalDataCache.Module,
        GlobalDataCacheMock
      )
    end

    test "retrieves all stop and route info from the V3 API", %{conn: conn} do
      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{
            "line-Red" => %MBTAV3API.Line{
              id: "line-Red",
              color: "DA291C",
              long_name: "Red Line",
              short_name: "",
              sort_order: 10_010,
              text_color: "FFFFFF"
            }
          },
          pattern_ids_by_stop: %{"70076" => ["Red-1-1", "Red-3-1"]},
          routes: %{
            "Red" => %MBTAV3API.Route{
              id: "Red",
              color: "DA291C",
              direction_destinations: ["Ashmont/Braintree", "Alewife"],
              direction_names: ["South", "North"],
              line_id: "line-Red",
              long_name: "Red Line",
              type: :heavy_rail
            }
          },
          route_patterns: %{
            "Red-1-1" => %MBTAV3API.RoutePattern{
              id: "Red-1-1",
              direction_id: 1,
              name: "Ashmont - Alewife",
              representative_trip_id: "canonical-Red-C2-1",
              route_id: "Red",
              sort_order: 100_101_001
            }
          },
          stops: %{
            "place-pktrm" => %MBTAV3API.Stop{
              id: "place-pktrm",
              latitude: 42.356395,
              location_type: :station,
              longitude: -71.062424,
              name: "Park Street",
              child_stop_ids: ["70076"],
              connecting_stop_ids: ["10000"]
            },
            "70076" => %MBTAV3API.Stop{
              id: "70076",
              name: "Park Street",
              location_type: :stop,
              parent_station_id: "place-pktrm"
            }
          },
          trips: %{
            "canonical-Red-C2-1" => %MBTAV3API.Trip{
              headsign: "Alewife",
              stop_ids: 70_094..70_062//-2 |> Enum.map(&to_string/1)
            }
          }
        }
      end)

      conn = get(conn, "/api/global")
      stop_response = json_response(conn, 200)

      assert %{
               "lines" => lines,
               "pattern_ids_by_stop" => pattern_ids,
               "routes" => routes,
               "route_patterns" => route_patterns,
               "stops" => stops,
               "trips" => trips
             } = stop_response

      park_st_station = stops["place-pktrm"]

      assert %{
               "id" => "place-pktrm",
               "name" => "Park Street",
               "location_type" => "station",
               "latitude" => 42.356395,
               "longitude" => -71.062424,
               "child_stop_ids" => child_ids,
               "connecting_stop_ids" => connecting_ids
             } = park_st_station

      park_st_rl_platform = stops["70076"]

      assert %{
               "id" => "70076",
               "name" => "Park Street",
               "location_type" => "stop",
               "parent_station_id" => "place-pktrm"
             } = park_st_rl_platform

      assert child_ids |> Enum.member?("70076")
      assert connecting_ids |> Enum.member?("10000")

      park_st_rl_patterns = Map.get(pattern_ids, Map.get(park_st_rl_platform, "id"))

      assert Enum.any?(park_st_rl_patterns, &(&1 == "Red-1-1"))
      assert Enum.any?(park_st_rl_patterns, &(&1 == "Red-3-1"))

      red_line_pattern = Map.get(route_patterns, "Red-1-1")

      assert %{
               "direction_id" => 1,
               "id" => "Red-1-1",
               "name" => "Ashmont - Alewife",
               "representative_trip_id" => red_line_trip_id,
               "route_id" => "Red",
               "sort_order" => 100_101_001
             } = red_line_pattern

      assert %{"headsign" => "Alewife", "stop_ids" => trip_stop_ids} = trips[red_line_trip_id]

      assert Enum.count(trip_stop_ids) == 17
      assert trip_stop_ids |> Enum.member?("70070")

      assert %{
               "Red" => %{
                 "color" => "DA291C",
                 "direction_destinations" => ["Ashmont/Braintree", "Alewife"],
                 "direction_names" => ["South", "North"],
                 "id" => "Red",
                 "line_id" => "line-Red",
                 "long_name" => "Red Line",
                 "type" => "heavy_rail"
               }
             } = routes

      assert %{
               "line-Red" => %{
                 "color" => "DA291C",
                 "id" => "line-Red",
                 "long_name" => "Red Line",
                 "short_name" => "",
                 "sort_order" => 10_010,
                 "text_color" => "FFFFFF"
               }
             } = lines
    end
  end
end

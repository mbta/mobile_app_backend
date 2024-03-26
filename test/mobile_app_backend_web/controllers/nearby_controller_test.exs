defmodule MobileAppBackendWeb.NearbyControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "GET /api/nearby unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "returns stop and route patterns with expected fields", %{conn: conn} do
      stop1 = build(:stop, %{id: "stop1", name: "Stop 1"})
      stop2 = build(:stop, %{id: "stop2", name: "Stop 2"})
      route = build(:route, %{id: "66"})

      t1 = build(:trip, id: "t1", stop_ids: [stop1.id], headsign: "Headsign 1")

      rp1 =
        build(:route_pattern, %{
          route_id: route.id,
          id: "rp1",
          representative_trip_id: t1.id
        })

      t2 = build(:trip, %{id: "t2", stop_ids: [stop1.id, stop2.id], headsign: "Headsign 2"})

      rp2 =
        build(:route_pattern, %{
          route_id: route.id,
          id: "rp2",
          representative_trip_id: t2.id
        })

      RepositoryMock
      |> expect(:stops, 2, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:route_type) do
          [:light_rail, :heavy_rail, :bus, :ferry] ->
            ok_response([stop1, stop2])

          _ ->
            ok_response([])
        end
      end)

      RepositoryMock
      |> expect(:route_patterns, fn _params, _opts ->
        ok_response([rp1, rp2], [t1, t2])
      end)

      conn =
        get(conn, "/api/nearby", %{
          latitude: 42.281219333648,
          longitude: -71.17594685509955
        })

      %{
        "stops" => stops,
        "route_patterns" => route_patterns,
        "pattern_ids_by_stop" => pattern_ids_by_stop,
        "trips" => trips
      } =
        json_response(conn, 200)

      assert [
               %{"id" => "stop1", "name" => "Stop 1"},
               %{"id" => "stop2", "name" => "Stop 2"}
             ] = stops

      assert %{
               "rp1" => %{
                 "id" => "rp1",
                 "route_id" => "66",
                 "representative_trip_id" => "t1"
               },
               "rp2" => %{
                 "id" => "rp2",
                 "route_id" => "66",
                 "representative_trip_id" => "t2"
               }
             } = route_patterns

      assert %{
               "t1" => %{
                 "headsign" => "Headsign 1",
                 "route_pattern_id" => nil,
                 "stop_ids" => nil
               },
               "t2" => %{
                 "headsign" => "Headsign 2",
                 "route_pattern_id" => nil,
                 "stop_ids" => nil
               }
             } = trips

      assert %{"stop1" => ["rp1", "rp2"], "stop2" => ["rp2"]} = pattern_ids_by_stop
    end

    test "includes both physical and logical platforms at stops with both", %{conn: conn} do
      parent_station =
        build(:stop, id: "place-forhl", child_stop_ids: ["70001", "Forest Hills-01"])

      logical_platform = build(:stop, id: "70001", parent_station_id: "place-forhl")
      physical_platform = build(:stop, id: "Forest Hills-01", parent_station_id: "place-forhl")

      RepositoryMock
      |> expect(:stops, 2, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:route_type) do
          [:light_rail, :heavy_rail, :bus, :ferry] ->
            ok_response([logical_platform, physical_platform], [parent_station])

          _ ->
            ok_response([])
        end
      end)

      trip =
        build(:trip,
          id: "canonical-Orange-C1-1",
          stop_ids: [logical_platform.id],
          headsign: "Oak Grove"
        )

      pattern =
        build(:route_pattern, %{
          route_id: "Orange",
          id: "Orange-3-1",
          representative_trip_id: trip.id
        })

      RepositoryMock
      |> expect(:route_patterns, fn _params, _opts ->
        ok_response([pattern], [trip])
      end)

      conn =
        get(conn, "/api/nearby", %{
          latitude: 1.2,
          longitude: -3.4
        })

      %{"stops" => stops} = json_response(conn, 200)

      assert [
               %{"id" => "70001"},
               %{"id" => "Forest Hills-01"}
             ] = stops
    end

    test "includes out of range sibling stops for any stops in range", %{conn: conn} do
      parentStopId = "parent"
      inRangeStopId = "inRangeSibling"
      outOfRangeStopId = "outOfRangeSibling"

      parent =
        build(:stop, %{
          id: parentStopId,
          name: "Stop 1",
          location_type: :station,
          child_stop_ids: [inRangeStopId, outOfRangeStopId]
        })

      inRangeSibling =
        build(:stop, %{id: inRangeStopId, name: "Stop 1", parent_station_id: parentStopId})

      outOfRangeSibling =
        build(:stop, %{id: outOfRangeStopId, name: "Stop 2", parent_station_id: parentStopId})

      route = build(:route, %{id: "66"})

      t1 = build(:trip, id: "t1", stop_ids: [inRangeSibling.id], headsign: "Headsign 1")

      rp1 =
        build(:route_pattern, %{
          route_id: route.id,
          id: "rp1",
          representative_trip_id: t1.id
        })

      t2 = build(:trip, %{id: "t2", stop_ids: [outOfRangeSibling.id], headsign: "Headsign 2"})

      rp2 =
        build(:route_pattern, %{
          route_id: route.id,
          id: "rp2",
          representative_trip_id: t2.id
        })

      RepositoryMock
      |> expect(:stops, 2, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:route_type) do
          [:light_rail, :heavy_rail, :bus, :ferry] ->
            ok_response([inRangeSibling], [parent, outOfRangeSibling])

          _ ->
            ok_response([])
        end
      end)

      RepositoryMock
      |> expect(:route_patterns, fn _params, _opts ->
        ok_response([rp1, rp2], [t1, t2, route])
      end)

      conn = get(conn, "/api/nearby", %{latitude: 42.095734, longitude: -71.019708})

      %{
        "stops" => stops,
        "parent_stops" => parent_stops
      } =
        json_response(conn, 200)

      assert [%{"id" => ^inRangeStopId}, %{"id" => ^outOfRangeStopId}] = stops
      assert %{^parentStopId => %{"id" => ^parentStopId}} = parent_stops
    end
  end

  describe "GET /api/nearby integration tests" do
    test "retrieves nearby stop and route info from the V3 API", %{conn: conn} do
      conn =
        get(conn, "/api/nearby", %{
          latitude: 42.281219333648,
          longitude: -71.17594685509955
        })

      %{
        "stops" => stops,
        "route_patterns" => route_patterns,
        "pattern_ids_by_stop" => pattern_ids_by_stop,
        "routes" => routes,
        "trips" => trips
      } =
        json_response(conn, 200)

      assert 21 = length(stops)
      assert 21 = length(Map.keys(pattern_ids_by_stop))
      assert 24 = length(Map.keys(route_patterns))

      assert 24 =
               pattern_ids_by_stop
               |> Map.values()
               |> Enum.flat_map(& &1)
               |> Enum.uniq()
               |> length()

      assert %{
               "id" => "67120",
               "latitude" => 42.28101,
               "longitude" => -71.177035,
               "name" => "Millennium Park"
             } = List.first(stops)

      assert %{
               "direction_id" => 0,
               "id" => "36-1-0",
               "name" => "Forest Hills Station - Millennium Park",
               "route_id" => "36",
               "sort_order" => 503_600_040,
               "representative_trip_id" => trip_id
             } = Map.get(route_patterns, "36-1-0")

      assert %{"headsign" => "Millennium Park"} = Map.get(trips, trip_id)

      assert %{
               "36" => %{
                 "color" => "FFC72C",
                 "direction_destinations" => [
                   "Millennium Park or VA Hospital",
                   "Forest Hills Station"
                 ],
                 "direction_names" => ["Outbound", "Inbound"],
                 "id" => "36",
                 "long_name" => "Millennium Park or VA Hospital - Forest Hills Station",
                 "short_name" => "36",
                 "sort_order" => 50_360,
                 "text_color" => "000000",
                 "type" => "bus"
               }
             } = routes

      assert ["37-3-1", "37-D-0", "37-_-1", "52-4-1", "52-5-1"] =
               Map.get(pattern_ids_by_stop, "833") |> Enum.sort()
    end

    test "includes parent stop info from the V3 API", %{conn: conn} do
      conn = get(conn, "/api/nearby", %{latitude: 42.562535, longitude: -70.869116})

      assert %{
               "parent_stops" => %{
                 "place-GB-0198" => %{
                   "id" => "place-GB-0198",
                   "latitude" => 42.562171,
                   "longitude" => -70.869254,
                   "name" => "Montserrat"
                 }
               },
               "stops" => [
                 %{"id" => "GB-0198", "parent_station_id" => "place-GB-0198"},
                 %{"id" => "GB-0198-01", "parent_station_id" => "place-GB-0198"},
                 %{"id" => "GB-0198-02", "parent_station_id" => "place-GB-0198"},
                 %{"id" => "GB-0198-B3", "parent_station_id" => "place-GB-0198"},
                 %{"id" => "GB-0198-B2", "parent_station_id" => "place-GB-0198"}
               ],
               "route_patterns" => %{},
               "pattern_ids_by_stop" => %{} = pattern_ids_by_stop
             } = json_response(conn, 200)

      assert Map.keys(pattern_ids_by_stop) == [
               "GB-0198-01",
               "GB-0198-02",
               "GB-0198-B2",
               "GB-0198-B3"
             ]
    end
  end
end

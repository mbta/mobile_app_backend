defmodule MobileAppBackendWeb.NearbyControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Test.Support.Sigils
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  setup_all do
    Mox.defmock(RepositoryMock, for: MBTAV3API.Repository)
    :ok
  end

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
            {:ok, to_full_map([stop1, stop2])}

          _ ->
            {:ok, to_full_map()}
        end
      end)

      RepositoryMock
      |> expect(:route_patterns, fn _params, _opts ->
        {:ok, to_full_map([t1, rp1, t2, rp2])}
      end)

      RepositoryMock
      |> expect(:alerts, fn _params, _opts -> {:ok, to_full_map()} end)

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

      assert 22 = length(stops)
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
               "stops" => [
                 %{"id" => "GB-0198-01", "parent_station_id" => "place-GB-0198"},
                 %{"id" => "GB-0198-02", "parent_station_id" => "place-GB-0198"},
                 %{"id" => "place-GB-0198"},
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

    test "includes out of range sibling stops for any stops in range", %{conn: conn} do
      conn = get(conn, "/api/nearby", %{latitude: 42.095734, longitude: -71.019708})

      assert %{
               "stops" => [
                 %{
                   "id" => "MM-0186-CS",
                   "latitude" => 42.106555,
                   "longitude" => -71.022001,
                   "name" => "Montello",
                   "parent_station_id" => "place-MM-0186"
                 },
                 %{
                   "id" => "MM-0186-S",
                   "name" => "Montello",
                   "parent_station_id" => "place-MM-0186"
                 },
                 %{
                   "id" => "place-MM-0186",
                   "name" => "Montello",
                   "child_stop_ids" => ["39870", "MM-0186", "MM-0186-CS", "MM-0186-S"]
                 },
                 %{"id" => "39870", "name" => "Montello", "parent_station_id" => "place-MM-0186"},
                 %{
                   "id" => "MM-0200-CS",
                   "name" => "Brockton",
                   "parent_station_id" => "place-MM-0200"
                 },
                 %{
                   "id" => "MM-0200-S",
                   "name" => "Brockton",
                   "parent_station_id" => "place-MM-0200"
                 },
                 %{
                   "id" => "place-MM-0200",
                   "name" => "Brockton",
                   "child_stop_ids" => ["MM-0200", "MM-0200-CS", "MM-0200-S"]
                 }
               ],
               "route_patterns" => %{
                 "230-3-0" => %{
                   "direction_id" => 0,
                   "id" => "230-3-0",
                   "name" => "Quincy Center Station - Montello Station",
                   "route_id" => "230",
                   "sort_order" => 523_000_000
                 },
                 "230-3-1" => %{
                   "direction_id" => 1,
                   "id" => "230-3-1",
                   "name" => "Montello Station - Quincy Center Station",
                   "route_id" => "230",
                   "sort_order" => 523_001_000
                 },
                 "230-5-0" => %{
                   "direction_id" => 0,
                   "id" => "230-5-0",
                   "name" => "Quincy Center Station - Montello Station via Holbrook Ct",
                   "route_id" => "230",
                   "sort_order" => 523_000_040
                 },
                 "230-5-1" => %{
                   "direction_id" => 1,
                   "id" => "230-5-1",
                   "name" => "Montello Station - Quincy Center Station via Holbrook Ct",
                   "route_id" => "230",
                   "sort_order" => 523_001_040
                 },
                 "CR-Middleborough-52b80476-0" => %{
                   "name" => "South Station - Middleborough/Lakeville"
                 },
                 "CR-Middleborough-75bed2bb-1" => %{
                   "name" => "Middleborough/Lakeville - South Station"
                 },
                 "CapeFlyer-C1-0" => %{"name" => "South Station - Hyannis"},
                 "CapeFlyer-C1-1" => %{"name" => "Hyannis - South Station"}
               },
               "pattern_ids_by_stop" => %{
                 "39870" => [
                   "230-3-0",
                   "230-3-1",
                   "230-5-0",
                   "230-5-1"
                 ],
                 "MM-0186-CS" => ["CR-Middleborough-75bed2bb-1"],
                 "MM-0186-S" => ["CR-Middleborough-52b80476-0"],
                 "MM-0200-CS" => ["CR-Middleborough-75bed2bb-1", "CapeFlyer-C1-1"],
                 "MM-0200-S" => ["CR-Middleborough-52b80476-0", "CapeFlyer-C1-0"]
               },
               "routes" => %{
                 "230" => %{
                   "color" => "FFC72C",
                   "direction_destinations" => [
                     "Montello Station",
                     "Quincy Center Station"
                   ],
                   "direction_names" => ["Outbound", "Inbound"],
                   "id" => "230",
                   "long_name" => "Montello Station - Quincy Center Station",
                   "short_name" => "230",
                   "sort_order" => 52_300,
                   "text_color" => "000000"
                 }
               }
             } =
               json_response(conn, 200)
    end

    test "includes alerts", %{conn: conn} do
      conn =
        get(conn, "/api/nearby", %{
          latitude: 42.388400,
          longitude: -71.119149,
          source: "v3",
          radius: 0.01,
          now: ~B[2024-02-09 16:00:00] |> DateTime.to_iso8601()
        })

      assert %{"stops" => stops, "alerts" => alerts} = json_response(conn, :ok)

      assert Enum.all?(
               stops,
               &(&1["id"] == "place-portr" or &1["parent_station_id"] == "place-portr")
             )

      assert [
               %{
                 "active_period" => _,
                 "effect" => "shuttle",
                 "effect_name" => nil,
                 "id" => "553081",
                 "informed_entity" => informed_entities,
                 "lifecycle" => "new"
               }
             ] = Enum.sort_by(alerts, & &1["id"])

      assert Enum.find(informed_entities, &(&1["stop"] == "place-portr"))
    end
  end
end

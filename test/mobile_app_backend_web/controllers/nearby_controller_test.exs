defmodule MobileAppBackendWeb.NearbyControllerTest do
  use MobileAppBackendWeb.ConnCase
  import Test.Support.Sigils

  setup do
    Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
    :ok
  end

  describe "GET /api/nearby" do
    test "retrieves nearby stop and route info from the V3 API", %{conn: conn} do
      conn =
        get(conn, "/api/nearby", %{
          latitude: 42.281219333648,
          longitude: -71.17594685509955
        })

      %{
        "stops" => stops,
        "route_patterns" => route_patterns,
        "pattern_ids_by_stop" => pattern_ids_by_stop
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
               "route" => %{
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
               },
               "sort_order" => 503_600_040,
               "representative_trip" => %{"headsign" => "Millennium Park"}
             } = Map.get(route_patterns, "36-1-0")

      assert ["37-D-0", "37-_-1", "37-3-1", "52-5-1", "52-4-1"] =
               Map.get(pattern_ids_by_stop, "833")
    end

    test "includes parent stop info from the V3 API", %{conn: conn} do
      conn = get(conn, "/api/nearby", %{latitude: 42.562535, longitude: -70.869116})

      assert %{
               "stops" => [
                 %{
                   "id" => "GB-0198-01",
                   "parent_station" =>
                     %{
                       "id" => "place-GB-0198",
                       "latitude" => 42.562171,
                       "longitude" => -70.869254,
                       "name" => "Montserrat"
                     } = parent_station
                 },
                 %{"id" => "GB-0198-02", "parent_station" => parent_station},
                 %{"id" => "GB-0198-B3", "parent_station" => parent_station},
                 %{"id" => "GB-0198-B2", "parent_station" => parent_station}
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
                   "name" => "Montello"
                 },
                 %{"id" => "MM-0186-S", "name" => "Montello"},
                 %{"id" => "39870", "name" => "Montello"},
                 %{"id" => "MM-0200-CS", "name" => "Brockton"},
                 %{"id" => "MM-0200-S", "name" => "Brockton"}
               ],
               "route_patterns" => %{
                 "230-3-0" => %{
                   "direction_id" => 0,
                   "id" => "230-3-0",
                   "name" => "Quincy Center Station - Montello Station",
                   "route" =>
                     %{
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
                     } = route_230,
                   "sort_order" => 523_000_000
                 },
                 "230-3-1" => %{
                   "direction_id" => 1,
                   "id" => "230-3-1",
                   "name" => "Montello Station - Quincy Center Station",
                   "route" => route_230,
                   "sort_order" => 523_001_000
                 },
                 "230-5-0" => %{
                   "direction_id" => 0,
                   "id" => "230-5-0",
                   "name" => "Quincy Center Station - Montello Station via Holbrook Ct",
                   "route" => route_230,
                   "sort_order" => 523_000_040
                 },
                 "230-5-1" => %{
                   "direction_id" => 1,
                   "id" => "230-5-1",
                   "name" => "Montello Station - Quincy Center Station via Holbrook Ct",
                   "route" => route_230,
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
                   "230-5-0",
                   "230-3-1",
                   "230-5-1"
                 ],
                 "MM-0186-CS" => ["CR-Middleborough-75bed2bb-1"],
                 "MM-0186-S" => ["CR-Middleborough-52b80476-0"],
                 "MM-0200-CS" => ["CR-Middleborough-75bed2bb-1", "CapeFlyer-C1-1"],
                 "MM-0200-S" => ["CR-Middleborough-52b80476-0", "CapeFlyer-C1-0"]
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
               &(&1["id"] == "place-portr" or &1["parent_station"]["id"] == "place-portr")
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

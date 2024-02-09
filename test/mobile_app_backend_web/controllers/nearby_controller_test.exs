defmodule MobileAppBackendWeb.NearbyControllerTest do
  use MobileAppBackendWeb.ConnCase

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

      assert %{
               "stops" => [
                 %{
                   "id" => "67120",
                   "latitude" => 42.28101,
                   "longitude" => -71.177035,
                   "name" => "Millennium Park"
                 },
                 %{"id" => "129", "name" => "Rivermoor St @ Charles Park Rd"},
                 %{"id" => "137", "name" => "Charles Park Rd @ Rivermoor St"},
                 %{"id" => "10830", "name" => "5 Charles Park Rd"},
                 %{"id" => "10821", "name" => "Charles Park Rd @ VFW Pkwy"},
                 %{"id" => "120", "name" => "Rivermoor St @ Industrial Park"},
                 %{"id" => "85565", "name" => "Baker St opp Varick Rd"},
                 %{"id" => "10820", "name" => "Veterans Hospital West Roxbury"},
                 %{"id" => "8394", "name" => "Baker St @ Varick Rd"},
                 %{"id" => "85566", "name" => "Baker St @ Amesbury St"},
                 %{"id" => "85564", "name" => "Baker St @ Capital St"},
                 %{"id" => "8393", "name" => "Baker St @ Rumford Rd"},
                 %{"id" => "853", "name" => "Vermont St @ Baker St"},
                 %{"id" => "833", "name" => "Baker St @ Lasell St"},
                 %{"id" => "85563", "name" => "Baker St @ VFW Pkwy"},
                 %{"id" => "834", "name" => "Lasell St @ Temple St"},
                 %{"id" => "85567", "name" => "Baker St @ Cutter Rd"},
                 %{"id" => "8392", "name" => "Baker St @ Cutter Rd"},
                 %{"id" => "NB-0080-S", "name" => "West Roxbury"},
                 %{"id" => "NB-0080-B1", "name" => "West Roxbury"},
                 %{"id" => "NB-0080-B0", "name" => "West Roxbury"}
               ],
               "route_patterns" => %{
                 "36-1-0" => %{
                   "direction_id" => 0,
                   "id" => "36-1-0",
                   "name" => "Forest Hills Station - Millennium Park",
                   "route" =>
                     %{
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
                     } = route_36,
                   "sort_order" => 503_600_040
                 },
                 "36-1-1" => %{
                   "direction_id" => 1,
                   "id" => "36-1-1",
                   "name" => "Millennium Park - Forest Hills Station",
                   "route" => route_36,
                   "sort_order" => 503_601_040
                 },
                 "36-5-0" => %{
                   "direction_id" => 0,
                   "id" => "36-5-0",
                   "name" => "Forest Hills Station - Millennium Park",
                   "route" => route_36,
                   "sort_order" => 503_600_060
                 },
                 "36-5-1" => %{
                   "direction_id" => 1,
                   "id" => "36-5-1",
                   "name" => "Millennium Park - Forest Hills Station",
                   "route" => route_36,
                   "sort_order" => 503_601_060
                 },
                 "36-8-0" => %{"name" => "Forest Hills Station - VA Hospital, West Roxbury"},
                 "36-8-1" => %{"name" => "VA Hospital, West Roxbury - Forest Hills Station"},
                 "37-3-1" => %{"name" => "LaGrange St & Corey St - Forest Hills Station"},
                 "37-D-0" => %{"name" => "Forest Hills Station - LaGrange St & Corey St"},
                 "37-_-0" => %{"name" => "Forest Hills Station - Baker St & Vermont St"},
                 "37-_-1" => %{"name" => "Baker St & Vermont St - Forest Hills Station"},
                 "52-4-0" => %{"name" => "Watertown - Charles River Loop via Meadowbrook Rd"},
                 "52-4-1" => %{"name" => "Charles River Loop - Watertown via Meadowbrook Rd"},
                 "52-5-0" => %{"name" => "Watertown - Dedham Mall via Meadowbrook Rd"},
                 "52-5-1" => %{"name" => "Dedham Mall - Watertown via Meadowbrook Rd"},
                 "CR-Needham-68a3e69b-1" => %{"name" => "Needham Heights - Forest Hills"},
                 "CR-Needham-7f6dbefb-0" => %{"name" => "Forest Hills - Needham Heights"},
                 "CR-Needham-C1-0" => %{"name" => "South Station - Needham Heights"},
                 "CR-Needham-C1-1" => %{"name" => "Needham Heights - South Station"},
                 "CR-Needham-a6552e0a-0" => %{"name" => "South Station - Needham Heights"},
                 "CR-Needham-d774fb34-1" => %{"name" => "Needham Heights - South Station"}
               },
               "pattern_ids_by_stop" => %{
                 "120" => ["36-5-0", "36-5-1"],
                 "129" => ["36-5-1"],
                 "137" => ["36-1-0", "36-5-0"],
                 "833" => ["37-D-0", "37-_-1", "37-3-1", "52-5-1", "52-4-1"],
                 "834" => ["37-D-0", "37-_-1", "37-3-1"],
                 "853" => ["37-_-0", "37-D-0", "37-_-1", "37-3-1"],
                 "8392" => ["52-5-1", "52-4-1"],
                 "8393" => ["52-5-1", "52-4-1"],
                 "8394" => ["52-5-1", "52-4-1"],
                 "10820" => ["36-8-0", "36-1-0", "36-5-0", "36-8-1"],
                 "10821" => ["36-1-1", "36-5-1"],
                 "10830" => ["36-1-0", "36-5-0"],
                 "67120" => ["36-1-0", "36-1-1"],
                 "85563" => ["52-5-0", "52-4-0"],
                 "85564" => ["52-5-0", "52-4-0"],
                 "85565" => ["52-5-0", "52-4-0"],
                 "85566" => ["52-5-0", "52-4-0"],
                 "85567" => ["52-5-0", "52-4-0"],
                 "NB-0080-S" => [
                   "CR-Needham-a6552e0a-0",
                   "CR-Needham-7f6dbefb-0",
                   "CR-Needham-69669b59-0",
                   "CR-Needham-C1-0",
                   "CR-Needham-d774fb34-1",
                   "CR-Needham-68a3e69b-1",
                   "CR-Needham-a01e12e1-1",
                   "CR-Needham-C1-1"
                 ]
               }
             } =
               json_response(conn, 200)
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
                       "name" => "Montserrat",
                       "parent_station" => nil
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
  end
end

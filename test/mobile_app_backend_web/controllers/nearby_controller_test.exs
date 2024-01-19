defmodule MobileAppBackendWeb.NearbyControllerTest do
  use MobileAppBackendWeb.ConnCase

  setup do
    Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
    :ok
  end

  describe "GET /api/nearby" do
    test "retrieves nearby stop and route info", %{conn: conn} do
      conn =
        get(conn, "/api/nearby", %{latitude: 42.281877070443166, longitude: -71.18020826779917})

      assert %{
               "stops" => [
                 %{
                   "id" => "67120",
                   "latitude" => 42.28101,
                   "longitude" => -71.177035,
                   "name" => "Millennium Park"
                 },
                 %{"id" => "120", "name" => "Rivermoor St @ Industrial Park"},
                 %{"id" => "129", "name" => "Rivermoor St @ Charles Park Rd"},
                 %{"id" => "137", "name" => "Charles Park Rd @ Rivermoor St"},
                 %{"id" => "10830", "name" => "5 Charles Park Rd"},
                 %{"id" => "10821", "name" => "Charles Park Rd @ VFW Pkwy"}
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
                       "text_color" => "000000"
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
                 }
               },
               "pattern_ids_by_stop" => %{
                 "120" => ["36-5-0", "36-5-1"],
                 "129" => ["36-5-1"],
                 "137" => ["36-1-0", "36-5-0"],
                 "10821" => ["36-1-1", "36-5-1"],
                 "10830" => ["36-1-0", "36-5-0"],
                 "67120" => ["36-1-0", "36-1-1"]
               }
             } =
               json_response(conn, 200)
    end
  end
end

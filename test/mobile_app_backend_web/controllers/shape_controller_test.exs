defmodule MobileAppBackendWeb.ShapeControllerTest do
  alias MBTAV3API.Route
  use MobileAppBackendWeb.ConnCase

  setup do
    Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
    :ok
  end

  describe "GET /api/shapes/rail" do
    test "retrieves all stop and route info from the V3 API", %{conn: conn} do
      conn = get(conn, "/api/shapes/rail")
      stop_response = json_response(conn, 200)

      assert %{"routes" => routes} = stop_response

      assert 21 = length(routes)

      route_patterns =
        Enum.flat_map(routes, fn route ->
          assert route["type"] in ["light_rail", "heavy_rail", "commuter_rail"]
          assert %{"route_patterns" => route_patterns} = route

          route_patterns
        end)

      Enum.each(route_patterns, fn route_pattern ->
        assert %{"representative_trip" => trip} = route_pattern
        assert %{"shape" => %{"polyline" => polyline}} = trip
        assert length(Polyline.decode(polyline)) > 0
      end)

      assert Enum.any?(route_patterns, &(&1["typicality"] == "typical"))
      assert Enum.any?(route_patterns, &(&1["typicality"] == "atypical"))
      assert Enum.any?(route_patterns, &(&1["typicality"] == "diversion"))
    end
  end
end

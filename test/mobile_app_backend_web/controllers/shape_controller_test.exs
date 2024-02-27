defmodule MobileAppBackendWeb.ShapeControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "GET /api/shapes/rail unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "returns routes with route patterns and shapes", %{conn: conn} do
      trip1 =
        build(:trip, %{
          id: "Blue-trip-1",
          shape: build(:shape, %{id: "Blue-shape-1", polyline: "ykoaGt{wpL@FCFCIDE"})
        })

      trip2 =
        build(:trip, %{
          id: "Blue-trip-2",
          shape: build(:shape, %{id: "Blue-shape-2", polyline: "wjoaGr~vpLl@y@Tr@[j@g@e@"})
        })

      pattern1 = build(:route_pattern, %{id: "Blue-1", representative_trip: trip1})
      pattern2 = build(:route_pattern, %{id: "Blue-2", representative_trip: trip2})

      route =
        build(:route, %{
          id: "Blue",
          route_patterns: [pattern1, pattern2]
        })

      RepositoryMock
      |> expect(:routes, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:type) do
          [:light_rail, :heavy_rail, :commuter_rail] -> {:ok, [route]}
          _ -> {:ok, []}
        end
      end)

      conn = get(conn, "/api/shapes/rail")

      %{"routes" => routes} = json_response(conn, 200)

      assert [%{"id" => "Blue", "route_patterns" => patterns}] = routes

      assert [
               %{
                 "id" => "Blue-1",
                 "representative_trip" => %{
                   "id" => "Blue-trip-1",
                   "shape" => %{"id" => "Blue-shape-1", "polyline" => "ykoaGt{wpL@FCFCIDE"}
                 }
               },
               %{
                 "id" => "Blue-2",
                 "representative_trip" => %{
                   "id" => "Blue-trip-2",
                   "shape" => %{
                     "id" => "Blue-shape-2",
                     "polyline" => "wjoaGr~vpLl@y@Tr@[j@g@e@"
                   }
                 }
               }
             ] = patterns
    end
  end

  describe "GET /api/shapes/rail integration tests" do
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

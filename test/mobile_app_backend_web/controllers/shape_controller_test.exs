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
      shape1 = build(:shape, %{id: "Blue-shape-1", polyline: "ykoaGt{wpL@FCFCIDE"})
      trip1 = build(:trip, %{id: "Blue-trip-1", shape_id: shape1.id})

      shape2 = build(:shape, %{id: "Blue-shape-2", polyline: "wjoaGr~vpLl@y@Tr@[j@g@e@"})
      trip2 = build(:trip, %{id: "Blue-trip-2", shape_id: shape2.id})

      pattern1 = build(:route_pattern, %{id: "Blue-1", representative_trip_id: trip1.id})
      pattern2 = build(:route_pattern, %{id: "Blue-2", representative_trip_id: trip2.id})

      route =
        build(:route, %{
          id: "Blue",
          route_pattern_ids: [pattern1.id, pattern2.id]
        })

      RepositoryMock
      |> expect(:routes, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:type) do
          [:light_rail, :heavy_rail, :commuter_rail] ->
            ok_response([route], [pattern1, pattern2, shape1, shape2, trip1, trip2])

          _ ->
            ok_response([])
        end
      end)

      conn = get(conn, "/api/shapes/rail")

      %{
        "routes" => routes,
        "route_patterns" => route_patterns,
        "shapes" => shapes,
        "trips" => trips
      } = json_response(conn, 200)

      assert [%{"id" => "Blue", "route_pattern_ids" => ["Blue-1", "Blue-2"]}] = routes

      assert %{
               "Blue-1" => %{
                 "id" => "Blue-1",
                 "representative_trip_id" => "Blue-trip-1"
               },
               "Blue-2" => %{
                 "id" => "Blue-2",
                 "representative_trip_id" => "Blue-trip-2"
               }
             } = route_patterns

      assert %{
               "Blue-trip-1" => %{
                 "id" => "Blue-trip-1",
                 "shape_id" => "Blue-shape-1"
               },
               "Blue-trip-2" => %{
                 "id" => "Blue-trip-2",
                 "shape_id" => "Blue-shape-2"
               }
             } = trips

      assert %{
               "Blue-shape-1" => %{"id" => "Blue-shape-1", "polyline" => "ykoaGt{wpL@FCFCIDE"},
               "Blue-shape-2" => %{
                 "id" => "Blue-shape-2",
                 "polyline" => "wjoaGr~vpLl@y@Tr@[j@g@e@"
               }
             } =
               shapes
    end
  end

  describe "GET /api/shapes/rail integration tests" do
    test "retrieves all stop and route info from the V3 API", %{conn: conn} do
      conn = get(conn, "/api/shapes/rail")
      stop_response = json_response(conn, 200)

      assert %{
               "routes" => routes,
               "route_patterns" => route_patterns,
               "shapes" => shapes,
               "trips" => trips
             } =
               stop_response

      assert 21 = length(routes)

      route_patterns = Map.values(route_patterns)

      Enum.each(route_patterns, fn route_pattern ->
        trip_id = route_pattern["representative_trip_id"]
        trip = trips[trip_id]
        shape_id = trip["shape_id"]
        shape = shapes[shape_id]
        polyline = shape["polyline"]
        assert length(Polyline.decode(polyline)) > 0
      end)

      assert Enum.any?(route_patterns, &(&1["typicality"] == "typical"))
      assert Enum.any?(route_patterns, &(&1["typicality"] == "atypical"))
      assert Enum.any?(route_patterns, &(&1["typicality"] == "diversion"))
    end
  end
end

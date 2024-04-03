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

  describe "GET /api/shapes/map-friendly/rail unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "returns route segments for the most canonical direction 0 route patterns with the associated shape",
         %{conn: conn} do
      red_route = build(:route, id: "Red")
      andrew = build(:stop, id: "andrew", location_type: :station)
      jfk = build(:stop, id: "jfk/umass", location_type: :station)

      jfk_child_1 =
        build(:stop, id: "jfk/umass-1", location_type: :stop, parent_station_id: jfk.id)

      jfk_child_2 =
        build(:stop, id: "jfk/umass-2", location_type: :stop, parent_station_id: jfk.id)

      savin = build(:stop, id: "savin_hill", location_type: :station)
      north_quincy = build(:stop, id: "north_quincy", location_type: :station)

      ashmont_shape = build(:shape, id: "ashmont_shape", polyline: "ashmont_shape_polyline")
      braintree_shape = build(:shape, id: "braintree_shape", polyline: "braintree_shape_polyline")

      ashmont_trip =
        build(:trip,
          id: "ashmont_trip",
          stop_ids: [andrew.id, jfk_child_1.id, savin.id],
          shape_id: "ashmont_shape"
        )

      braintree_trip =
        build(:trip,
          id: "braintree_trip",
          stop_ids: [andrew.id, jfk_child_2.id, north_quincy.id],
          shape_id: "braintree_shape"
        )

      ashmont_rp =
        build(:route_pattern,
          id: "red-ashmont",
          representative_trip_id: ashmont_trip.id,
          route_id: "Red",
          canonical: true,
          typicality: :typical
        )

      braintree_rp =
        build(:route_pattern,
          id: "red-braintree",
          representative_trip_id: braintree_trip.id,
          route_id: "Red",
          canonical: true,
          typicality: :typical
        )

      rl_diversion_rp =
        build(:route_pattern,
          id: "rl_diversion",
          route_id: "Red",
          typicality: :diversion,
          canonical: false
        )

      rl_canonical_direction_1 =
        build(:route_pattern,
          id: "rl_diversion",
          route_id: "Red",
          typicality: :typical,
          canonical: true,
          direction_id: 1
        )

      RepositoryMock
      |> expect(:routes, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:type) do
          [:light_rail, :heavy_rail, :commuter_rail] ->
            ok_response([red_route], [
              ashmont_rp,
              braintree_rp,
              rl_diversion_rp,
              rl_canonical_direction_1
            ])
        end
      end)

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          ["ashmont_trip", "braintree_trip"] ->
            ok_response([ashmont_trip, braintree_trip], [
              ashmont_shape,
              braintree_shape,
              andrew,
              jfk,
              jfk_child_1,
              jfk_child_2,
              savin,
              north_quincy
            ])
        end
      end)

      conn = get(conn, "/api/shapes/map-friendly/rail")

      %{"map_friendly_route_shapes" => map_friendly_route_shapes} = json_response(conn, 200)

      assert [
               %{
                 "source_route_pattern_id" => "red-ashmont",
                 "source_route_id" => "Red",
                 "route_segments" => [
                   %{
                     "id" => "andrew-savin_hill",
                     "source_route_pattern_id" => "red-ashmont",
                     "stop_ids" => ["andrew", "jfk/umass", "savin_hill"],
                     "other_patterns_by_stop_id" => %{
                       "andrew" => [
                         %{"route_id" => "Red", "route_pattern_id" => "red-braintree"}
                       ],
                       "jfk/umass" => [
                         %{"route_id" => "Red", "route_pattern_id" => "red-braintree"}
                       ]
                     }
                   }
                 ],
                 "shape" => %{"id" => "ashmont_shape", "polyline" => "ashmont_shape_polyline"}
               },
               %{
                 "source_route_pattern_id" => "red-braintree",
                 "source_route_id" => "Red",
                 "route_segments" => [
                   %{
                     "id" => "jfk/umass-north_quincy",
                     "source_route_id" => "Red",
                     "source_route_pattern_id" => "red-braintree",
                     "stop_ids" => ["jfk/umass", "north_quincy"],
                     "other_patterns_by_stop_id" => %{}
                   }
                 ],
                 "shape" => %{"id" => "braintree_shape", "polyline" => "braintree_shape_polyline"}
               }
             ] =
               map_friendly_route_shapes
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
        stop_ids = trip["stop_ids"]
        assert length(stop_ids) > 0
      end)

      assert Enum.any?(route_patterns, &(&1["typicality"] == "typical"))
      assert Enum.any?(route_patterns, &(&1["typicality"] == "atypical"))
      assert Enum.any?(route_patterns, &(&1["typicality"] == "diversion"))
    end
  end
end

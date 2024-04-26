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

    test "when separate_overlapping_segments is true, returns non-overlapping segments for the most canonical direction 0 route patterns with the associated shape",
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

      conn =
        get(conn, "/api/shapes/rail", %{"separate_overlapping_segments" => "true"})

      %{"map_friendly_route_shapes" => map_friendly_route_shapes} = json_response(conn, 200)

      assert [
               %{
                 "route_id" => "Red",
                 "route_shapes" => [
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
                     "shape" => %{
                       "id" => "braintree_shape",
                       "polyline" => "braintree_shape_polyline"
                     }
                   }
                 ]
               }
             ] =
               map_friendly_route_shapes
    end

    test "when separate_overlapping_segments is not set, returns a segment per route pattern for the most canonical direction 0 route patterns with the associated shape",
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

      conn =
        get(conn, "/api/shapes/rail")

      %{"map_friendly_route_shapes" => map_friendly_route_shapes} = json_response(conn, 200)

      assert [
               %{
                 "route_id" => "Red",
                 "route_shapes" => [
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
                         "id" => "andrew-north_quincy",
                         "source_route_id" => "Red",
                         "source_route_pattern_id" => "red-braintree",
                         "stop_ids" => ["andrew", "jfk/umass", "north_quincy"],
                         "other_patterns_by_stop_id" => %{
                           "andrew" => [
                             %{"route_id" => "Red", "route_pattern_id" => "red-ashmont"}
                           ],
                           "jfk/umass" => [
                             %{"route_id" => "Red", "route_pattern_id" => "red-ashmont"}
                           ]
                         }
                       }
                     ],
                     "shape" => %{
                       "id" => "braintree_shape",
                       "polyline" => "braintree_shape_polyline"
                     }
                   }
                 ]
               }
             ] =
               map_friendly_route_shapes
    end

    test "sorts by route sort order",
         %{conn: conn} do
      red_route = build(:route, id: "Red", sort_order: 1)

      andrew = build(:stop, id: "andrew", location_type: :station)
      jfk = build(:stop, id: "jfk/umass", location_type: :station)

      ashmont_shape = build(:shape, id: "ashmont_shape", polyline: "ashmont_shape_polyline")

      ashmont_trip =
        build(:trip,
          id: "ashmont_trip",
          stop_ids: [andrew.id, jfk.id],
          shape_id: "ashmont_shape"
        )

      ashmont_rp =
        build(:route_pattern,
          id: "red-ashmont",
          representative_trip_id: ashmont_trip.id,
          route_id: "Red",
          canonical: true,
          typicality: :typical
        )

      orange_route = build(:route, id: "Orange", sort_order: 2)

      oak_grove = build(:stop, id: "oak", location_type: :station)
      malden = build(:stop, id: "malden", location_type: :station)

      ol_shape = build(:shape, id: "ol_shape", polyline: "ol_polyline")

      ol_trip =
        build(:trip,
          id: "ol_trip",
          stop_ids: [oak_grove.id, malden.id],
          shape_id: "ol_shape"
        )

      ol_rp =
        build(:route_pattern,
          id: "ol-rp",
          representative_trip_id: ol_trip.id,
          route_id: "Orange",
          canonical: true,
          typicality: :typical
        )

      RepositoryMock
      |> expect(:routes, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:type) do
          [:light_rail, :heavy_rail, :commuter_rail] ->
            ok_response([orange_route, red_route], [
              ashmont_rp,
              ol_rp
            ])
        end
      end)

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          ["ol_trip", "ashmont_trip"] ->
            ok_response([ol_trip, ashmont_trip], [
              ashmont_shape,
              ol_shape,
              andrew,
              jfk,
              oak_grove,
              malden
            ])
        end
      end)

      conn = get(conn, "/api/shapes/rail")

      %{"map_friendly_route_shapes" => map_friendly_route_shapes} = json_response(conn, 200)

      assert [
               %{
                 "route_id" => "Red"
               },
               %{"route_id" => "Orange"}
             ] =
               map_friendly_route_shapes
    end
  end

  describe "GET /api/shapes unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    defp mock_rl_data do
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

      RepositoryMock
      |> expect(:routes, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:stop) do
          ["jfk/umass"] ->
            ok_response([red_route], [
              ashmont_rp,
              braintree_rp
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
    end

    test "when param stop_id is set should separate overlapping segments, returns non-overlapping routes segments for routes at that stop",
         %{conn: conn} do
      mock_rl_data()

      conn =
        get(conn, "/api/shapes", %{
          "stop_id" => "jfk/umass",
          "separate_overlapping_segments" => "true"
        })

      %{"map_friendly_route_shapes" => map_friendly_route_shapes} = json_response(conn, 200)

      assert [
               %{
                 "route_id" => "Red",
                 "route_shapes" => [
                   %{
                     "source_route_pattern_id" => "red-ashmont",
                     "route_segments" => [
                       %{
                         "stop_ids" => ["andrew", "jfk/umass", "savin_hill"]
                       }
                     ],
                     "shape" => %{"id" => "ashmont_shape", "polyline" => "ashmont_shape_polyline"}
                   },
                   %{
                     "source_route_pattern_id" => "red-braintree",
                     "route_segments" => [
                       %{
                         "stop_ids" => ["jfk/umass", "north_quincy"]
                       }
                     ],
                     "shape" => %{
                       "id" => "braintree_shape",
                       "polyline" => "braintree_shape_polyline"
                     }
                   }
                 ]
               }
             ] =
               map_friendly_route_shapes
    end

    test "when param stop_id is set shouldn't separate overlapping segments, returns full routes segments for routes at that stop",
         %{conn: conn} do
      mock_rl_data()

      conn =
        get(conn, "/api/shapes", %{"stop_id" => "jfk/umass"})

      %{"map_friendly_route_shapes" => map_friendly_route_shapes} = json_response(conn, 200)

      assert [
               %{
                 "route_id" => "Red",
                 "route_shapes" => [
                   %{
                     "source_route_pattern_id" => "red-ashmont",
                     "route_segments" => [
                       %{
                         "stop_ids" => ["andrew", "jfk/umass", "savin_hill"]
                       }
                     ],
                     "shape" => %{"polyline" => "ashmont_shape_polyline"}
                   },
                   %{
                     "source_route_pattern_id" => "red-braintree",
                     "route_segments" => [
                       %{
                         "stop_ids" => ["andrew", "jfk/umass", "north_quincy"]
                       }
                     ],
                     "shape" => %{
                       "polyline" => "braintree_shape_polyline"
                     }
                   }
                 ]
               }
             ] =
               map_friendly_route_shapes
    end
  end
end

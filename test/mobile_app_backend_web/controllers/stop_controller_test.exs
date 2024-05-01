defmodule MobileAppBackendWeb.StopControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "GET /api/stop/map unit tests" do
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

      jfk_child_3 =
        build(:stop, id: "jfk/umass-3", location_type: :generic_node, parent_station_id: jfk.id)

      jfk_child_4 =
        build(:stop, id: "jfk/umass-4", location_type: :entrance_exit, parent_station_id: jfk.id)

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
          direction_id: 0,
          canonical: true,
          typicality: :typical
        )

      braintree_rp =
        build(:route_pattern,
          id: "red-braintree",
          representative_trip_id: braintree_trip.id,
          route_id: "Red",
          direction_id: 1,
          canonical: false,
          typicality: :diversion
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

      RepositoryMock
      |> expect(:stops, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "jfk/umass" ->
            ok_response([], [jfk_child_1, jfk_child_2, jfk_child_3, jfk_child_4])
        end
      end)
    end

    test "when param stop_id is set shouldn't separate overlapping segments, returns full routes segments for all route patterns at that stop",
         %{conn: conn} do
      mock_rl_data()

      conn =
        get(conn, "/api/stop/map", %{"stop_id" => "jfk/umass"})

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

    test "child stops are included",
         %{conn: conn} do
      mock_rl_data()

      conn =
        get(conn, "/api/stop/map", %{"stop_id" => "jfk/umass"})

      %{"child_stops" => child_stops} = json_response(conn, 200)

      assert %{
               "jfk/umass-1" => %{"id" => "jfk/umass-1"},
               "jfk/umass-2" => %{"id" => "jfk/umass-2"},
               "jfk/umass-4" => %{"id" => "jfk/umass-4"}
             } = child_stops
    end
  end
end

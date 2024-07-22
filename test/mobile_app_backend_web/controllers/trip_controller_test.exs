defmodule MobileAppBackendWeb.TripControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "GET /api/trip unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "when trip found, return trip data",
         %{conn: conn} do
      trip =
        build(:trip,
          id: "trip_id",
          stop_ids: ["Harvard", "Nubian"],
          route_id: "66",
          route_pattern_id: "66-6-1",
          direction_id: "1",
          shape_id: "66_shape",
          headsign: "Nubian via Allston"
        )

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "trip_id" ->
            ok_response([trip])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/trip", %{"trip_id" => trip.id})

      response = json_response(conn, 200)

      assert %{
               "trip" => %{
                 "id" => "trip_id",
                 "stop_ids" => ["Harvard", "Nubian"],
                 "direction_id" => "1",
                 "route_id" => "66",
                 "route_pattern_id" => "66-6-1",
                 "shape_id" => "66_shape",
                 "headsign" => "Nubian via Allston"
               }
             } =
               response
    end

    test "when trip found without related stops, falls back to route pattern stops",
         %{conn: conn} do
      route_pattern =
        build(:route_pattern, %{id: "66-6-1", representative_trip_id: "rep_trip"})

      trip =
        build(:trip,
          id: "trip_id",
          stop_ids: [],
          route_id: "66",
          route_pattern_id: "66-6-1",
          direction_id: "1",
          shape_id: "66_shape",
          headsign: "Nubian via Allston"
        )

      rep_trip = build(:trip, %{id: "rep_trip", stop_ids: ["Harvard", "Nubian"]})

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "trip_id" ->
            ok_response([trip], [route_pattern, rep_trip])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/trip", %{"trip_id" => trip.id})

      response = json_response(conn, 200)

      assert %{
               "trip" => %{
                 "id" => "trip_id",
                 "stop_ids" => ["Harvard", "Nubian"],
                 "direction_id" => "1",
                 "route_id" => "66",
                 "route_pattern_id" => "66-6-1",
                 "shape_id" => "66_shape",
                 "headsign" => "Nubian via Allston"
               }
             } =
               response
    end

    test "when trip found without related stops but route pattern doesn't resolve, returns empty list",
         %{conn: conn} do
      trip =
        build(:trip,
          id: "trip_id",
          stop_ids: [],
          route_id: "66",
          route_pattern_id: "66-6-1",
          direction_id: "1",
          shape_id: "66_shape",
          headsign: "Nubian via Allston"
        )

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "trip_id" ->
            ok_response([trip], [])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/trip", %{"trip_id" => trip.id})

      response = json_response(conn, 200)

      assert %{
               "trip" => %{
                 "id" => "trip_id",
                 "stop_ids" => [],
                 "direction_id" => "1",
                 "route_id" => "66",
                 "route_pattern_id" => "66-6-1",
                 "shape_id" => "66_shape",
                 "headsign" => "Nubian via Allston"
               }
             } =
               response
    end

    @tag capture_log: true
    test "when trip not found, 404 error",
         %{conn: conn} do
      RepositoryMock
      |> expect(:trips, 1, fn _params, _opts ->
        ok_response([])
      end)

      conn =
        get(conn, "/api/trip", %{"trip_id" => "unknown_trip_id"})

      response = json_response(conn, 404)

      assert %{"code" => 404, "message" => "Trip not found: unknown_trip_id"} =
               response
    end
  end

  describe "GET /api/trip/map unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "when trip found with related stops, returns shape and stop data",
         %{conn: conn} do
      trip =
        build(:trip,
          id: "trip_id",
          route_id: "66",
          route_pattern_id: "66-0-1",
          direction_id: "1",
          shape_id: "66_shape",
          stop_ids: ["Harvard", "Nubian"]
        )

      route_pattern = build(:route_pattern, %{id: "66-0-1"})

      shape = build(:shape, id: trip.shape_id, polyline: "66_shape_polyline")

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "trip_id" ->
            ok_response([trip], [shape, route_pattern])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/trip/map", %{"trip_id" => trip.id})

      response = json_response(conn, 200)

      assert %{
               "shape_with_stops" => %{
                 "direction_id" => "1",
                 "route_id" => "66",
                 "route_pattern_id" => "66-0-1",
                 "shape" => %{"id" => "66_shape", "polyline" => "66_shape_polyline"},
                 "stop_ids" => ["Harvard", "Nubian"]
               }
             } =
               response
    end

    test "when trip found without related stops, falls back to route pattern stops",
         %{conn: conn} do
      route_pattern =
        build(:route_pattern, %{id: "66-0-1", representative_trip_id: "rep_trip"})

      trip =
        build(:trip,
          id: "trip_id",
          route_id: "66",
          route_pattern_id: "66-0-1",
          direction_id: "1",
          shape_id: "66_shape",
          stop_ids: []
        )

      rep_trip = build(:trip, %{id: "rep_trip", stop_ids: ["Harvard", "Nubian"]})

      shape = build(:shape, id: trip.shape_id, polyline: "66_shape_polyline")

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "trip_id" ->
            ok_response([trip], [shape, route_pattern, rep_trip])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/trip/map", %{"trip_id" => trip.id})

      response = json_response(conn, 200)

      assert %{
               "shape_with_stops" => %{
                 "direction_id" => "1",
                 "route_id" => "66",
                 "route_pattern_id" => "66-0-1",
                 "shape" => %{"id" => "66_shape", "polyline" => "66_shape_polyline"},
                 "stop_ids" => ["Harvard", "Nubian"]
               }
             } =
               response
    end

    test "when trip found without related stops but route pattern doesn't resolve, returns empty list",
         %{conn: conn} do
      trip =
        build(:trip,
          id: "trip_id",
          route_id: "66",
          route_pattern_id: "66-0-1",
          direction_id: "1",
          shape_id: "66_shape",
          stop_ids: []
        )

      shape = build(:shape, id: trip.shape_id, polyline: "66_shape_polyline")

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "trip_id" ->
            ok_response([trip], [shape])

          _ ->
            ok_response([])
        end
      end)

      conn =
        get(conn, "/api/trip/map", %{"trip_id" => trip.id})

      response = json_response(conn, 200)

      assert %{
               "shape_with_stops" => %{
                 "direction_id" => "1",
                 "route_id" => "66",
                 "route_pattern_id" => "66-0-1",
                 "shape" => %{"id" => "66_shape", "polyline" => "66_shape_polyline"},
                 "stop_ids" => []
               }
             } =
               response
    end

    @tag capture_log: true
    test "when trip not found, 404 error",
         %{conn: conn} do
      RepositoryMock
      |> expect(:trips, 1, fn _params, _opts ->
        ok_response([])
      end)

      conn =
        get(conn, "/api/trip/map", %{"trip_id" => "unknown_trip_id"})

      response = json_response(conn, 404)

      assert %{"code" => 404, "message" => "Trip not found: unknown_trip_id"} =
               response
    end
  end
end

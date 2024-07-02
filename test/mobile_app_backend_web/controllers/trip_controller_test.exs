defmodule MobileAppBackendWeb.TripControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "GET /api/trip/map unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    defp mock_trip_data do
      trip66 =
        build(:trip,
          id: "trip_id",
          route_id: "66",
          route_pattern_id: "66-0-1",
          direction_id: "1",
          shape_id: "66_shape",
          stop_ids: ["Harvard", "Nubian"]
        )

      shape = build(:shape, id: trip66.shape_id, polyline: "66_shape_polyline")

      RepositoryMock
      |> expect(:trips, 1, fn params, _opts ->
        case params
             |> Keyword.get(:filter)
             |> Keyword.get(:id) do
          "trip_id" ->
            ok_response([trip66], [shape])

          _ ->
            ok_response([])
        end
      end)

      %{trip: trip66}
    end

    test "when trip found, returns shape and stop data",
         %{conn: conn} do
      %{trip: trip} = mock_trip_data()

      conn =
        get(conn, "/api/trip/map", %{"trip_id" => trip.id})

      response = json_response(conn, 200)

      assert %{
               "type" => "single_shape",
               "direction_id" => "1",
               "route_id" => "66",
               "route_pattern_id" => "66-0-1",
               "shape" => %{"id" => "66_shape", "polyline" => "66_shape_polyline"},
               "stop_ids" => ["Harvard", "Nubian"]
             } =
               response
    end

    @tag capture_log: true
    test "when trip not found, 404 error",
         %{conn: conn} do
      mock_trip_data()

      conn =
        get(conn, "/api/trip/map", %{"trip_id" => "unknown_trip_id"})

      response = json_response(conn, 404)

      assert %{"type" => "unknown", "message" => "Trip not found: unknown_trip_id"} =
               response
    end
  end
end

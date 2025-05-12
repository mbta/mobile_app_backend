defmodule MobileAppBackendWeb.RouteControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "GET /api/route/stops unit tests" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    defp mock_route_data do
      andrew = build(:stop, id: "andrew")
      jfk = build(:stop, id: "jfk/umass")
      savin = build(:stop, id: "savin_hill")
      north_quincy = build(:stop, id: "north_quincy")

      RepositoryMock
      |> expect(:stops, 2, fn
        [filter: [route: "Red", direction_id: "0"], fields: _], _opts ->
          ok_response([andrew, jfk, savin, north_quincy])

        [filter: [route: "Red", direction_id: "1"], fields: _], _opts ->
          ok_response([north_quincy, savin, jfk, andrew])
      end)
    end

    defp mock_multi_route_data do
      stop_a = build(:stop, id: "stopA")
      stop_b = build(:stop, id: "stopB")
      stop_c = build(:stop, id: "stopC")
      stop_d = build(:stop, id: "stopD")

      RepositoryMock
      |> expect(:stops, 1, fn
        [filter: [route: "route1,route2", direction_id: "0"], fields: _], _opts ->
          ok_response([stop_a, stop_b, stop_c, stop_d])
      end)
    end

    test "list of stop IDs is returned in a direction along a route",
         %{conn: conn} do
      mock_route_data()

      conn0 =
        get(conn, "/api/route/stops", %{"route_id" => "Red", "direction_id" => 0})

      data0 = json_response(conn0, 200)

      assert %{"stop_ids" => ["andrew", "jfk/umass", "savin_hill", "north_quincy"]} = data0

      conn1 =
        get(conn, "/api/route/stops", %{"route_id" => "Red", "direction_id" => 1})

      data1 = json_response(conn1, 200)

      assert %{"stop_ids" => ["north_quincy", "savin_hill", "jfk/umass", "andrew"]} = data1
    end

    test "joined list of stop IDs is returned when multiple routes are passed in",
         %{conn: conn} do
      mock_multi_route_data()

      conn =
        get(conn, "/api/route/stops", %{"route_id" => "route1,route2", "direction_id" => 0})

      data = json_response(conn, 200)

      assert %{"stop_ids" => ["stopA", "stopB", "stopC", "stopD"]} = data
    end
  end
end

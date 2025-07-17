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

  describe "GET /api/route/stop-graph integration test" do
    setup do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      :ok
    end

    test "returns the correct list for the Providence/Stoughton Line outbound", %{conn: conn} do
      conn =
        get(conn, "/api/route/stop-graph", %{"route_id" => "CR-Providence", "direction_id" => 0})

      data = json_response(conn, 200)

      empty = %{
        "before" => false,
        "converging" => false,
        "current_stop" => false,
        "diverging" => false,
        "after" => false
      }

      forward = %{
        "before" => true,
        "converging" => false,
        "current_stop" => true,
        "diverging" => false,
        "after" => true
      }

      skip = %{forward | "current_stop" => false}

      assert data == [
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "stick_state" => %{
                       "left" => empty,
                       "right" => %{forward | "before" => false}
                     },
                     "stop_id" => "place-sstat"
                   },
                   %{
                     "stick_state" => %{"left" => empty, "right" => forward},
                     "stop_id" => "place-bbsta"
                   },
                   %{
                     "stick_state" => %{"left" => empty, "right" => forward},
                     "stop_id" => "place-rugg"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "stick_state" => %{"left" => empty, "right" => forward},
                     "stop_id" => "place-NEC-2203"
                   },
                   %{
                     "stick_state" => %{"left" => empty, "right" => forward},
                     "stop_id" => "place-DB-0095"
                   }
                 ],
                 "typical?" => false
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "stick_state" => %{"left" => empty, "right" => forward},
                     "stop_id" => "place-NEC-2173"
                   },
                   %{
                     "stick_state" => %{
                       "left" => %{skip | "before" => false, "diverging" => true},
                       "right" => %{forward | "diverging" => true}
                     },
                     "stop_id" => "place-NEC-2139"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => "Stoughton",
                 "stops" => [
                   %{
                     "stick_state" => %{"left" => skip, "right" => forward},
                     "stop_id" => "place-SB-0156"
                   },
                   %{
                     "stick_state" => %{"left" => skip, "right" => %{forward | "after" => false}},
                     "stop_id" => "place-SB-0189"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "stick_state" => %{"left" => forward, "right" => empty},
                     "stop_id" => "place-NEC-2108"
                   },
                   %{
                     "stick_state" => %{"left" => forward, "right" => empty},
                     "stop_id" => "place-NEC-2040"
                   },
                   %{
                     "stick_state" => %{"left" => forward, "right" => empty},
                     "stop_id" => "place-NEC-1969"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "stick_state" => %{"left" => forward, "right" => empty},
                     "stop_id" => "place-NEC-1919"
                   }
                 ],
                 "typical?" => false
               },
               %{
                 "name" => "Providence",
                 "stops" => [
                   %{
                     "stick_state" => %{"left" => forward, "right" => empty},
                     "stop_id" => "place-NEC-1891"
                   },
                   %{
                     "stick_state" => %{"left" => forward, "right" => empty},
                     "stop_id" => "place-NEC-1851"
                   },
                   %{
                     "stick_state" => %{"left" => forward, "right" => empty},
                     "stop_id" => "place-NEC-1768"
                   },
                   %{
                     "stick_state" => %{"left" => %{forward | "after" => false}, "right" => empty},
                     "stop_id" => "place-NEC-1659"
                   }
                 ],
                 "typical?" => true
               }
             ]
    end
  end
end

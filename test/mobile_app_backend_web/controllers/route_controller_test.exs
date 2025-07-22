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

      forward = fn s1, s2, s3, lane ->
        [
          %{
            "from_stop" => s1,
            "from_lane" => lane,
            "from_vpos" => "top",
            "to_stop" => s2,
            "to_lane" => lane,
            "to_vpos" => "center"
          },
          %{
            "from_stop" => s2,
            "from_lane" => lane,
            "from_vpos" => "center",
            "to_stop" => s3,
            "to_lane" => lane,
            "to_vpos" => "bottom"
          }
        ]
      end

      assert data == [
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "connections" => [
                       %{
                         "from_stop" => "place-sstat",
                         "from_lane" => "center",
                         "from_vpos" => "center",
                         "to_stop" => "place-bbsta",
                         "to_lane" => "center",
                         "to_vpos" => "bottom"
                       }
                     ],
                     "stop_id" => "place-sstat",
                     "stop_lane" => "center"
                   },
                   %{
                     "connections" =>
                       forward.("place-sstat", "place-bbsta", "place-rugg", "center"),
                     "stop_id" => "place-bbsta",
                     "stop_lane" => "center"
                   },
                   %{
                     "connections" =>
                       forward.("place-bbsta", "place-rugg", "place-NEC-2203", "center"),
                     "stop_id" => "place-rugg",
                     "stop_lane" => "center"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "connections" =>
                       forward.("place-rugg", "place-NEC-2203", "place-DB-0095", "center"),
                     "stop_id" => "place-NEC-2203",
                     "stop_lane" => "center"
                   },
                   %{
                     "connections" =>
                       forward.("place-NEC-2203", "place-DB-0095", "place-NEC-2173", "center"),
                     "stop_id" => "place-DB-0095",
                     "stop_lane" => "center"
                   }
                 ],
                 "typical?" => false
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "connections" =>
                       forward.("place-DB-0095", "place-NEC-2173", "place-NEC-2139", "center"),
                     "stop_id" => "place-NEC-2173",
                     "stop_lane" => "center"
                   },
                   %{
                     "connections" => [
                       %{
                         "from_stop" => "place-NEC-2173",
                         "from_lane" => "center",
                         "from_vpos" => "top",
                         "to_stop" => "place-NEC-2139",
                         "to_lane" => "center",
                         "to_vpos" => "center"
                       },
                       %{
                         "from_stop" => "place-NEC-2139",
                         "from_lane" => "center",
                         "from_vpos" => "center",
                         "to_stop" => "place-NEC-2108",
                         "to_lane" => "right",
                         "to_vpos" => "bottom"
                       },
                       %{
                         "from_stop" => "place-NEC-2139",
                         "from_lane" => "center",
                         "from_vpos" => "center",
                         "to_stop" => "place-SB-0156",
                         "to_lane" => "left",
                         "to_vpos" => "bottom"
                       }
                     ],
                     "stop_id" => "place-NEC-2139",
                     "stop_lane" => "center"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => "Stoughton",
                 "stops" => [
                   %{
                     "connections" =>
                       forward.("place-NEC-2139", "place-SB-0156", "place-SB-0189", "left") ++
                         [
                           %{
                             "from_stop" => "place-NEC-2139",
                             "from_lane" => "right",
                             "from_vpos" => "top",
                             "to_stop" => "place-NEC-2108",
                             "to_lane" => "right",
                             "to_vpos" => "bottom"
                           }
                         ],
                     "stop_id" => "place-SB-0156",
                     "stop_lane" => "left"
                   },
                   %{
                     "connections" => [
                       %{
                         "from_stop" => "place-SB-0156",
                         "from_lane" => "left",
                         "from_vpos" => "top",
                         "to_stop" => "place-SB-0189",
                         "to_lane" => "left",
                         "to_vpos" => "center"
                       },
                       %{
                         "from_stop" => "place-NEC-2139",
                         "from_lane" => "right",
                         "from_vpos" => "top",
                         "to_stop" => "place-NEC-2108",
                         "to_lane" => "right",
                         "to_vpos" => "bottom"
                       }
                     ],
                     "stop_id" => "place-SB-0189",
                     "stop_lane" => "left"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "connections" =>
                       forward.("place-NEC-2139", "place-NEC-2108", "place-NEC-2040", "right"),
                     "stop_id" => "place-NEC-2108",
                     "stop_lane" => "right"
                   },
                   %{
                     "connections" =>
                       forward.("place-NEC-2108", "place-NEC-2040", "place-NEC-1969", "right"),
                     "stop_id" => "place-NEC-2040",
                     "stop_lane" => "right"
                   },
                   %{
                     "connections" =>
                       forward.("place-NEC-2040", "place-NEC-1969", "place-NEC-1919", "right"),
                     "stop_id" => "place-NEC-1969",
                     "stop_lane" => "right"
                   }
                 ],
                 "typical?" => true
               },
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "connections" =>
                       forward.("place-NEC-1969", "place-NEC-1919", "place-NEC-1891", "right"),
                     "stop_id" => "place-NEC-1919",
                     "stop_lane" => "right"
                   }
                 ],
                 "typical?" => false
               },
               %{
                 "name" => "Providence",
                 "stops" => [
                   %{
                     "connections" =>
                       forward.("place-NEC-1919", "place-NEC-1891", "place-NEC-1851", "right"),
                     "stop_id" => "place-NEC-1891",
                     "stop_lane" => "right"
                   },
                   %{
                     "connections" =>
                       forward.("place-NEC-1891", "place-NEC-1851", "place-NEC-1768", "right"),
                     "stop_id" => "place-NEC-1851",
                     "stop_lane" => "right"
                   },
                   %{
                     "connections" =>
                       forward.("place-NEC-1851", "place-NEC-1768", "place-NEC-1659", "right"),
                     "stop_id" => "place-NEC-1768",
                     "stop_lane" => "right"
                   },
                   %{
                     "connections" => [
                       %{
                         "from_stop" => "place-NEC-1768",
                         "from_lane" => "right",
                         "from_vpos" => "top",
                         "to_stop" => "place-NEC-1659",
                         "to_lane" => "right",
                         "to_vpos" => "center"
                       }
                     ],
                     "stop_id" => "place-NEC-1659",
                     "stop_lane" => "right"
                   }
                 ],
                 "typical?" => true
               }
             ]
    end
  end
end

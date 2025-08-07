defmodule MobileAppBackendWeb.RouteControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase

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
            "to_stop" => s2,
            "from_lane" => lane,
            "to_lane" => lane,
            "from_vpos" => "top",
            "to_vpos" => "center"
          },
          %{
            "from_stop" => s2,
            "to_stop" => s3,
            "from_lane" => lane,
            "to_lane" => lane,
            "from_vpos" => "center",
            "to_vpos" => "bottom"
          }
        ]
        |> Enum.reject(&(is_nil(&1["from_stop"]) or is_nil(&1["to_stop"])))
      end

      assert data == [
               %{
                 "name" => nil,
                 "stops" => [
                   %{
                     "connections" => forward.(nil, "place-sstat", "place-bbsta", "center"),
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
                         "to_stop" => "place-NEC-2139",
                         "from_lane" => "center",
                         "to_lane" => "center",
                         "from_vpos" => "top",
                         "to_vpos" => "center"
                       },
                       %{
                         "from_stop" => "place-NEC-2139",
                         "to_stop" => "place-NEC-2108",
                         "from_lane" => "center",
                         "to_lane" => "right",
                         "from_vpos" => "center",
                         "to_vpos" => "bottom"
                       },
                       %{
                         "from_stop" => "place-NEC-2139",
                         "to_stop" => "place-SB-0156",
                         "from_lane" => "center",
                         "to_lane" => "left",
                         "from_vpos" => "center",
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
                             "to_stop" => "place-NEC-2108",
                             "from_lane" => "right",
                             "to_lane" => "right",
                             "from_vpos" => "top",
                             "to_vpos" => "bottom"
                           }
                         ],
                     "stop_id" => "place-SB-0156",
                     "stop_lane" => "left"
                   },
                   %{
                     "connections" =>
                       forward.("place-SB-0156", "place-SB-0189", nil, "left") ++
                         [
                           %{
                             "from_stop" => "place-NEC-2139",
                             "to_stop" => "place-NEC-2108",
                             "from_lane" => "right",
                             "to_lane" => "right",
                             "from_vpos" => "top",
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
                     "connections" => forward.("place-NEC-1768", "place-NEC-1659", nil, "right"),
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

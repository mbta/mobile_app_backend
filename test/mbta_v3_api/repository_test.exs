defmodule MBTAV3API.RepositoryTest do
  use ExUnit.Case

  import Mox

  alias MBTAV3API.Route
  alias MBTAV3API.{Alert, Repository, RoutePattern, Stop}
  import Test.Support.Sigils

  setup :verify_on_exit!

  test "alerts/2" do
    expect(
      MobileAppBackend.HTTPMock,
      :request,
      fn %Req.Request{url: %URI{path: "/alerts"}, options: %{params: params}} ->
        assert params == %{
                 "fields[alert]" =>
                   "active_period,cause,description,effect,effect_name,header,informed_entity,lifecycle,updated_at",
                 "filter[lifecycle]" => "NEW,ONGOING,ONGOING_UPCOMING",
                 "filter[stop]" =>
                   "9983,6542,1241,8281,place-boyls,8279,49002,6565,place-tumnl,145,place-pktrm,place-bbsta"
               }

        {:ok,
         Req.Response.json(%{
           data: [
             %{
               "attributes" => %{
                 "active_period" => [
                   %{"end" => "2024-02-08T19:12:40-05:00", "start" => "2024-02-08T14:38:00-05:00"}
                 ],
                 "cause" => "AMTRAK",
                 "description" => "Description 1",
                 "effect" => "DELAY",
                 "header" => "Header 1",
                 "informed_entity" => [
                   %{
                     "activities" => ["BOARD", "EXIT", "RIDE"],
                     "route" => "11",
                     "route_type" => 3
                   }
                 ],
                 "lifecycle" => "NEW",
                 "updated_at" => "2024-02-08T14:38:00-05:00"
               },
               "id" => "552825",
               "links" => %{"self" => "/alerts/552825"},
               "type" => "alert"
             },
             %{
               "attributes" => %{
                 "active_period" => [
                   %{"end" => "2024-02-08T19:12:40-05:00", "start" => "2024-02-08T12:55:00-05:00"}
                 ],
                 "cause" => "HURRICANE",
                 "description" => "Description 2",
                 "effect" => "DELAY",
                 "header" => "Header 2",
                 "informed_entity" => [
                   %{
                     "activities" => ["BOARD", "EXIT", "RIDE"],
                     "route" => "15",
                     "route_type" => 3
                   }
                 ],
                 "lifecycle" => "NEW",
                 "updated_at" => "2024-02-08T12:55:00-05:00"
               },
               "id" => "552803",
               "links" => %{"self" => "/alerts/552803"},
               "type" => "alert"
             }
           ]
         })}
      end
    )

    {:ok, %{data: alerts}} =
      Repository.alerts(
        filter: [
          lifecycle: [:new, :ongoing, :ongoing_upcoming],
          stop: [
            "9983",
            "6542",
            "1241",
            "8281",
            "place-boyls",
            "8279",
            "49002",
            "6565",
            "place-tumnl",
            "145",
            "place-pktrm",
            "place-bbsta"
          ]
        ]
      )

    assert alerts == [
             %Alert{
               id: "552825",
               active_period: [
                 %Alert.ActivePeriod{start: ~B[2024-02-08 14:38:00], end: ~B[2024-02-08 19:12:40]}
               ],
               cause: :amtrak,
               description: "Description 1",
               effect: :delay,
               header: "Header 1",
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "11",
                   route_type: :bus
                 }
               ],
               lifecycle: :new,
               updated_at: ~B[2024-02-08 14:38:00]
             },
             %Alert{
               id: "552803",
               active_period: [
                 %Alert.ActivePeriod{start: ~B[2024-02-08 12:55:00], end: ~B[2024-02-08 19:12:40]}
               ],
               cause: :hurricane,
               description: "Description 2",
               effect: :delay,
               header: "Header 2",
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "15",
                   route_type: :bus
                 }
               ],
               lifecycle: :new,
               updated_at: ~B[2024-02-08 12:55:00]
             }
           ]
  end

  test "route_patterns/2" do
    expect(
      MobileAppBackend.HTTPMock,
      :request,
      fn %Req.Request{url: %URI{path: "/route_patterns"}, options: %{params: _params}} ->
        {:ok,
         Req.Response.json(%{
           data: [
             %{
               "attributes" => %{
                 "direction_id" => 0,
                 "name" => "North Station - Rockport",
                 "sort_order" => 200_110_050,
                 "typicality" => 1
               },
               "id" => "CR-Newburyport-e54dc640-0",
               "relationships" => %{
                 "representative_trip" => %{
                   "data" => %{
                     "id" => "CR-649284-123",
                     "type" => "trip"
                   }
                 },
                 "route" => %{
                   "data" => %{
                     "id" => "CR-Newburyport",
                     "type" => "route"
                   }
                 }
               },
               "type" => "route_pattern"
             },
             %{
               "attributes" => %{
                 "direction_id" => 0,
                 "name" => "North Station - Rockport",
                 "sort_order" => 200_110_110,
                 "typicality" => 1
               },
               "id" => "CR-Newburyport-dd9f791d-0",
               "relationships" => %{
                 "representative_trip" => %{
                   "data" => %{
                     "id" => "CR-649341-103",
                     "type" => "trip"
                   }
                 },
                 "route" => %{
                   "data" => %{
                     "id" => "CR-Newburyport",
                     "type" => "route"
                   }
                 }
               },
               "type" => "route_pattern"
             }
           ]
         })}
      end
    )

    assert {:ok,
            %{
              data: [
                %RoutePattern{
                  id: "CR-Newburyport-e54dc640-0",
                  name: "North Station - Rockport",
                  direction_id: 0,
                  sort_order: 200_110_050,
                  route_id: "CR-Newburyport",
                  representative_trip_id: "CR-649284-123"
                },
                %RoutePattern{
                  id: "CR-Newburyport-dd9f791d-0",
                  name: "North Station - Rockport",
                  direction_id: 0,
                  sort_order: 200_110_110,
                  route_id: "CR-Newburyport",
                  representative_trip_id: "CR-649341-103"
                }
              ]
            }} = Repository.route_patterns([])
  end

  describe "routes/2" do
    test "fetches routes" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/routes"}, options: _params} ->
          {:ok,
           Req.Response.json(%{
             data: [
               %{
                 attributes: %{
                   color: "ED8B00",
                   description: "Rapid Transit",
                   direction_destinations: [
                     "Forest Hills",
                     "Oak Grove"
                   ],
                   direction_names: [
                     "South",
                     "North"
                   ],
                   fare_class: "Rapid Transit",
                   long_name: "Orange Line",
                   short_name: "",
                   sort_order: 10_020,
                   text_color: "FFFFFF",
                   type: 1
                 },
                 id: "Orange",
                 links: %{
                   self: "/routes/Orange"
                 },
                 relationships: %{
                   line: %{
                     data: %{
                       id: "line-Orange",
                       type: "line"
                     }
                   }
                 },
                 type: "route"
               }
             ]
           })}
        end
      )

      assert {:ok,
              %{
                data: [
                  %Route{
                    id: "Orange",
                    long_name: "Orange Line"
                  }
                ]
              }} = Repository.routes([])
    end

    test "overrides route color with line color" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{
             url: %URI{path: "/routes"},
             options: %{
               params: %{"include" => "line,route_patterns", "fields[route]" => "short_name"}
             }
           } ->
          {:ok,
           Req.Response.json(%{
             data: [
               %{
                 attributes: %{
                   color: "FFC72C",
                   description: "Rail Replacement Bus",
                   direction_destinations: [
                     "Forest Hills",
                     "Back Bay"
                   ],
                   direction_names: [
                     "South",
                     "North"
                   ],
                   fare_class: "Free",
                   long_name: "Forest Hills - Back Bay",
                   short_name: "Orange Line Shuttle",
                   sort_order: 60_491,
                   text_color: "000000",
                   type: 3
                 },
                 id: "Shuttle-BackBayForestHills",
                 links: %{
                   self: "/routes/Shuttle-BackBayForestHills"
                 },
                 relationships: %{
                   line: %{
                     data: %{
                       id: "line-Orange",
                       type: "line"
                     }
                   }
                 },
                 type: "route"
               }
             ],
             included: [
               %{
                 attributes: %{
                   color: "ED8B00",
                   long_name: "Orange Line",
                   short_name: "",
                   sort_order: 10_020,
                   text_color: "FFFFFF"
                 },
                 id: "line-Orange",
                 links: %{
                   self: "/lines/line-Orange"
                 },
                 type: "line"
               }
             ]
           })}
        end
      )

      assert {:ok,
              %{
                data: [
                  %Route{
                    id: "Shuttle-BackBayForestHills",
                    color: "ED8B00",
                    text_color: "FFFFFF"
                  }
                ]
              }} =
               Repository.routes(
                 include: [:line, :route_patterns],
                 fields: [route: [:short_name]]
               )
    end
  end

  test "stops/2" do
    expect(
      MobileAppBackend.HTTPMock,
      :request,
      fn %Req.Request{url: %URI{path: "/stops"}, options: %{params: _params}} ->
        {:ok,
         Req.Response.json([
           %{
             "attributes" => %{
               "latitude" => 42.3884,
               "location_type" => 0,
               "longitude" => -71.119149,
               "name" => "Porter"
             },
             "id" => "FR-0034-01",
             "relationships" => %{
               "parent_station" => %{
                 "data" => %{
                   "id" => "place-portr",
                   "type" => "stop"
                 }
               }
             },
             "type" => "stop"
           },
           %{
             "attributes" => %{
               "latitude" => 42.3884,
               "location_type" => 0,
               "longitude" => -71.119149,
               "name" => "Porter"
             },
             "id" => "FR-0034-02",
             "relationships" => %{
               "parent_station" => %{
                 "data" => %{
                   "id" => "place-portr",
                   "type" => "stop"
                 }
               }
             },
             "type" => "stop"
           }
         ])}
      end
    )

    assert {:ok,
            %{
              data: [
                %Stop{
                  id: "FR-0034-01",
                  name: "Porter",
                  parent_station_id: "place-portr"
                },
                %Stop{
                  id: "FR-0034-02",
                  name: "Porter",
                  parent_station_id: "place-portr"
                }
              ]
            }} = Repository.stops([])
  end
end

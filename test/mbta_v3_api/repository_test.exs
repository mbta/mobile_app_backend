defmodule MBTAV3API.RepositoryTest do
  use ExUnit.Case

  import Mox

  alias MBTAV3API.{Alert, Repository, RoutePattern, Stop}
  import Test.Support.Sigils

  setup :verify_on_exit!

  test "alerts/2" do
    expect(
      MobileAppBackend.HTTPMock,
      :request,
      fn %Req.Request{url: %URI{path: "/alerts"}, options: %{params: params}} ->
        assert params == %{
                 "fields[alert]" => "active_period,effect,effect_name,informed_entity,lifecycle",
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
                 "effect" => "DELAY",
                 "informed_entity" => [
                   %{
                     "activities" => ["BOARD", "EXIT", "RIDE"],
                     "route" => "11",
                     "route_type" => 3
                   }
                 ],
                 "lifecycle" => "NEW"
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
                 "effect" => "DELAY",
                 "informed_entity" => [
                   %{
                     "activities" => ["BOARD", "EXIT", "RIDE"],
                     "route" => "15",
                     "route_type" => 3
                   }
                 ],
                 "lifecycle" => "NEW"
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
               effect: :delay,
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "11",
                   route_type: :bus
                 }
               ],
               lifecycle: :new
             },
             %Alert{
               id: "552803",
               active_period: [
                 %Alert.ActivePeriod{start: ~B[2024-02-08 12:55:00], end: ~B[2024-02-08 19:12:40]}
               ],
               effect: :delay,
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "15",
                   route_type: :bus
                 }
               ],
               lifecycle: :new
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

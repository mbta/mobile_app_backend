defmodule MBTAV3API.RepositoryTest do
  use ExUnit.Case

  import Mox

  alias MBTAV3API.JsonApi
  alias MBTAV3API.JsonApi.Object
  alias MBTAV3API.{Repository, Route, RoutePattern, Schedule, Stop}

  setup :verify_on_exit!

  setup do
    MBTAV3API.RepositoryCache.flush()
    :ok
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

  describe "schedules/2" do
    test "returns cached response when given same request twice" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        # Only called once because first response is cached
        1,
        fn %Req.Request{url: %URI{path: "/schedules"}, options: %{params: _params}} ->
          {:ok,
           Req.Response.json(%{
             data: [
               %{
                 "attributes" => %{
                   "arrival_time" => "2024-03-13T01:07:00-04:00",
                   "departure_time" => "2024-03-13T01:07:00-04:00",
                   "drop_off_type" => 0,
                   "id" => "schedule-60565179-70159-90",
                   "pickup_type" => 0,
                   "route_id" => "Green-B",
                   "stop_id" => "70159",
                   "stop_sequence" => 90,
                   "trip_id" => "trip_1"
                 },
                 "id" => "sched_1",
                 "relationships" => %{
                   "trip" => %{
                     "data" => %{
                       "id" => "trip_1",
                       "type" => "trip"
                     }
                   }
                 },
                 "type" => "schedule"
               }
             ],
             included: [
               %{
                 "attributes" => %{
                   "headsign" => "Headsign",
                   "direction_id" => 1
                 },
                 "id" => "trip_1",
                 "type" => "trip"
               }
             ]
           })}
        end
      )

      assert {:ok,
              %{
                data: [
                  %Schedule{
                    id: "sched_1"
                  }
                ],
                included: %{trips: %{"trip_1" => %{id: "trip_1"}}}
              }} = Repository.schedules([])

      assert {:ok,
              %{
                data: [
                  %Schedule{
                    id: "sched_1"
                  }
                ],
                included: %{trips: %{"trip_1" => %{id: "trip_1"}}}
              }} = Repository.schedules([])
    end

    test "makes new request when new params passed" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/schedules"}, options: %{params: _params}} ->
          {:ok,
           Req.Response.json(%{
             data: [
               %{
                 "attributes" => %{
                   "arrival_time" => "2024-03-13T01:07:00-04:00",
                   "departure_time" => "2024-03-13T01:07:00-04:00",
                   "drop_off_type" => 0,
                   "id" => "schedule-60565179-70159-90",
                   "pickup_type" => 0,
                   "route_id" => "Green-B",
                   "stop_id" => "70159",
                   "stop_sequence" => 90,
                   "trip_id" => "trip_1"
                 },
                 "id" => "sched_1",
                 "relationships" => %{
                   "trip" => %{
                     "data" => %{
                       "id" => "trip_1",
                       "type" => "trip"
                     }
                   }
                 },
                 "type" => "schedule"
               }
             ],
             included: [
               %{
                 "attributes" => %{
                   "headsign" => "Headsign",
                   "direction_id" => 1
                 },
                 "id" => "trip_1",
                 "type" => "trip"
               }
             ]
           })}
        end
      )

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/schedules"}, options: %{params: _params}} ->
          {:ok,
           Req.Response.json(%{
             data: [],
             included: []
           })}
        end
      )

      assert {:ok,
              %{
                data: [
                  %Schedule{
                    id: "sched_1"
                  }
                ],
                included: %{trips: %{"trip_1" => %{id: "trip_1"}}}
              }} = Repository.schedules([])

      assert {:ok,
              %JsonApi.Response{
                data: [],
                included: Object.to_full_map([])
              }} == Repository.schedules(filter: [stop: "fake_stop"])
    end
  end
end

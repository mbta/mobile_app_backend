defmodule MobileAppBackend.Alerts.SummaryEntityBuilderTest do
  use ExUnit.Case

  alias MBTAV3API.Alert.InformedEntity
  alias MobileAppBackend.Alerts.SummaryEntity
  alias MobileAppBackend.Alerts.SummaryEntityBuilder
  alias MobileAppBackend.Alerts.SummaryEntityBuilder.Combination
  alias MobileAppBackend.GlobalDataCache

  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  import MobileAppBackend.Factory

  setup do
    verify_on_exit!()
    reassign_env(:mobile_app_backend, :base_url, "")
    reassign_env(:mobile_app_backend, :api_key, "")

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    MBTAV3API.RepositoryCache.delete_all()

    :ok
  end

  defp stop_response(stops) do
    {:ok,
     Req.Response.json(%{
       data:
         stops
         |> Enum.map(fn stop ->
           %{
             "attributes" => %{
               "address" => nil,
               "at_street" => nil,
               "description" => "Broadway - Red Line - Alewife",
               "latitude" => stop.latitude,
               "location_type" => 0,
               "longitude" => stop.longitude,
               "municipality" => "Boston",
               "name" => stop.name,
               "on_street" => nil,
               "platform_code" => nil,
               "platform_name" => stop.name,
               "vehicle_type" => 0,
               "wheelchair_boarding" => 1
             },
             "id" => stop.id,
             "relationships" =>
               if stop.parent_station_id do
                 %{
                   "parent_station" => %{
                     "data" => %{
                       "id" => stop.parent_station_id,
                       "type" => "stop"
                     }
                   }
                 }
               else
                 %{}
               end,
             "type" => "stop"
           }
         end)
     })}
  end

  defp schedule_response(schedules, trip, stops) do
    dt_or_nil = fn dt ->
      case dt do
        nil -> nil
        dt -> DateTime.to_iso8601(dt)
      end
    end

    {:ok,
     Req.Response.json(%{
       data:
         schedules
         |> Enum.map(fn schedule ->
           %{
             "attributes" => %{
               "arrival_time" => dt_or_nil.(schedule.arrival_time),
               "departure_time" => dt_or_nil.(schedule.departure_time),
               "drop_off_type" => 1,
               "id" => schedule.id,
               "pickup_type" => 0,
               "stop_headsign" => schedule.stop_headsign,
               "stop_sequence" => schedule.stop_sequence
             },
             "id" => schedule.id,
             "relationships" => %{
               "added_routes" => %{
                 "data" => []
               },
               "route" => %{
                 "data" => %{
                   "id" => schedule.route_id,
                   "type" => "route"
                 }
               },
               "trip" => %{
                 "data" => %{
                   "id" => schedule.trip_id,
                   "type" => "trip"
                 }
               },
               "stop" => %{
                 "data" => %{
                   "id" => schedule.stop_id,
                   "type" => "stop"
                 }
               }
             },
             "type" => "schedule"
           }
         end),
       included:
         [
           %{
             "attributes" => %{
               "headsign" => trip.headsign,
               "direction_id" => trip.direction_id
             },
             "id" => trip.id,
             "type" => "trip",
             "relationships" => %{
               "route" => %{
                 "data" => %{
                   "id" => trip.route_id,
                   "type" => "route"
                 }
               },
               "stops" => %{
                 "data" =>
                   trip.stop_ids
                   |> Enum.map(fn stop_id ->
                     %{
                       "id" => stop_id,
                       "type" => "stop"
                     }
                   end)
               }
             }
           }
         ] ++
           (stops
            |> Enum.map(fn stop ->
              %{
                "attributes" => %{
                  "latitude" => stop.latitude,
                  "location_type" => stop.location_type,
                  "longitude" => stop.longitude,
                  "name" => stop.name
                },
                "id" => stop.id,
                "type" => "stop"
              }
            end))
     })}
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  describe "build_all/4" do
    test "build basic alert" do
      now = DateTime.now!("America/New_York")

      stop = build(:stop, parent_station_id: nil)
      route = build(:route, type: :heavy_rail, long_name: "Red Line", short_name: "Red")
      trip = build(:trip, route_id: route.id, stop_ids: [stop.id])

      pattern =
        build(:route_pattern,
          route_id: route.id,
          representative_trip_id: trip.id,
          typicality: :typical
        )

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{stop.id => [pattern.id]},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: [pattern] |> Map.new(&{&1.id, &1}),
          stops: [stop] |> Map.new(&{&1.id, &1}),
          trips: [trip] |> Map.new(&{&1.id, &1})
        }
      end)

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/stops"}} ->
          stop_response([stop])
        end
      )

      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{route: route.id}]
        )

      alert_id = alert.id
      route_id = route.id

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: 0,
                   summary: "Service suspended on Red Line"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: nil,
                   direction_id: 0,
                   summary: "Service suspended on Red Line"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :card)
    end

    test "build trip alert" do
      now = ~B[2026-06-03 12:00:00]

      stop1 = build(:stop, parent_station_id: nil)
      stop2 = build(:stop, parent_station_id: nil)
      route = build(:route, type: :heavy_rail, long_name: "Red Line", short_name: "Red")
      representative_trip = build(:trip, route_id: route.id, stop_ids: [stop1.id])
      trip = build(:trip, route_id: route.id, stop_ids: [stop2.id])
      schedule = build(:schedule, trip_id: trip.id, route_id: route.id, stop_id: stop2.id)

      pattern =
        build(:route_pattern,
          route_id: route.id,
          representative_trip_id: representative_trip.id,
          typicality: :typical
        )

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{stop1.id => [pattern.id], stop2.id => [pattern.id]},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: [pattern] |> Map.new(&{&1.id, &1}),
          stops: [stop1, stop2] |> Map.new(&{&1.id, &1}),
          trips: [representative_trip] |> Map.new(&{&1.id, &1})
        }
      end)

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/schedules"}} ->
          schedule_response([schedule], trip, [stop2])
        end
      )

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/stops"}} ->
          stop_response([stop1, stop2])
        end
      )

      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{route: route.id, trip: trip.id}]
        )

      alert_id = alert.id
      route_id = route.id
      trip_id = trip.id

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: ^trip_id,
                   direction_id: 0,
                   summary:
                     "4:41 PM train from Harvard Sq @ Garden St - Dawes Island is suspended tomorrow due to maintenance"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: nil,
                   trip_id: ^trip_id,
                   direction_id: 0,
                   summary: "This train is suspended tomorrow due to maintenance"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :card)
    end

    test "build stop alert" do
      now = DateTime.now!("America/New_York")

      stop = build(:stop, parent_station_id: nil)
      route = build(:route, type: :heavy_rail, long_name: "Red Line", short_name: "Red")
      trip = build(:trip, route_id: route.id, stop_ids: [stop.id])

      pattern =
        build(:route_pattern,
          route_id: route.id,
          representative_trip_id: trip.id,
          typicality: :typical
        )

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{stop.id => [pattern.id]},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: [pattern] |> Map.new(&{&1.id, &1}),
          stops: [stop] |> Map.new(&{&1.id, &1}),
          trips: [trip] |> Map.new(&{&1.id, &1})
        }
      end)

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/stops"}} ->
          stop_response([stop])
        end
      )

      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{stop: stop.id}]
        )

      alert_id = alert.id
      route_id = route.id
      stop_id = stop.id

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: ^stop_id,
                   trip_id: nil,
                   direction_id: 0,
                   summary: "Service suspended at Harvard Sq @ Garden St - Dawes Island"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert %{
               ^alert_id => [
                 %SummaryEntity{
                   alert_id: ^alert_id,
                   route_id: ^route_id,
                   stop_id: ^stop_id,
                   trip_id: nil,
                   direction_id: 0,
                   summary: "Service suspended at Harvard Sq @ Garden St - Dawes Island"
                 }
               ]
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :card)
    end

    test "build route type alert" do
      now = DateTime.now!("America/New_York")

      stop1 = build(:stop, parent_station_id: nil)
      stop2 = build(:stop, parent_station_id: nil)

      route1 =
        build(:route, id: "route1", type: :heavy_rail, long_name: "Red Line", short_name: "Red")

      route2 =
        build(:route, id: "route2", type: :heavy_rail, long_name: "Blue Line", short_name: "Blue")

      trip1 = build(:trip, route_id: route1.id, stop_ids: [stop1.id])
      trip2 = build(:trip, route_id: route2.id, stop_ids: [stop2.id])

      pattern1 =
        build(:route_pattern,
          route_id: route1.id,
          representative_trip_id: trip1.id,
          typicality: :typical
        )

      pattern2 =
        build(:route_pattern,
          route_id: route2.id,
          representative_trip_id: trip2.id,
          typicality: :typical
        )

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{stop1.id => [pattern1.id], stop2.id => [pattern2.id]},
          routes: [route1, route2] |> Map.new(&{&1.id, &1}),
          route_patterns: [pattern1, pattern2] |> Map.new(&{&1.id, &1}),
          stops: [stop1, stop2] |> Map.new(&{&1.id, &1}),
          trips: [trip1, trip2] |> Map.new(&{&1.id, &1})
        }
      end)

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/stops"}} ->
          stop_response([stop1, stop2])
        end
      )

      global = GlobalDataCache.get_data()

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{route_type: 1}]
        )

      alert_id = alert.id
      route1_id = route1.id
      route2_id = route2.id

      assert %{
               ^alert_id => summary_entities
             } = SummaryEntityBuilder.build_all([alert], now, "en", global, :notification)

      assert [
               %SummaryEntity{
                 alert_id: ^alert_id,
                 route_id: ^route1_id,
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: 0,
                 summary: "Service suspended on Red Line"
               },
               %SummaryEntity{
                 alert_id: ^alert_id,
                 route_id: ^route2_id,
                 stop_id: nil,
                 trip_id: nil,
                 direction_id: 0,
                 summary: "Service suspended on Blue Line"
               }
             ] = summary_entities |> Enum.sort_by(& &1.route_id)
    end
  end

  describe "relevant_combinations/3" do
    test "splits route entities into both directions" do
      route = build(:route, type: :heavy_rail, long_name: "Red Line", short_name: "Red")

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: %{},
          stops: %{},
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      route_id = route.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id}
          ]
        )

      assert [
               %Combination{route: ^route_id, direction: 0},
               %Combination{route: ^route_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "splits stop entities into both directions" do
      stop = build(:stop, parent_station_id: nil)

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: %{},
          route_patterns: %{},
          stops: [stop] |> Map.new(&{&1.id, &1}),
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      stop_id = stop.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [%InformedEntity{stop: stop_id}]
        )

      assert [
               %Combination{stop: ^stop_id, direction: 0},
               %Combination{stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "trip entities set trip" do
      stop = build(:stop, parent_station_id: nil)
      route = build(:route, type: :heavy_rail, long_name: "Red Line", short_name: "Red")
      trip = build(:trip, route_id: route.id, stop_ids: [stop.id])

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: %{},
          stops: [stop] |> Map.new(&{&1.id, &1}),
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      route_id = route.id
      stop_id = stop.id
      trip_id = trip.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, stop: stop_id, trip: trip_id, direction_id: 1}
          ]
        )

      assert [%Combination{route: ^route_id, stop: ^stop_id, trip: ^trip_id, direction: 1}] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
    end

    test "creates a combination for every route with a route_type entity" do
      stop = build(:stop, parent_station_id: nil)
      route1 = build(:route, id: "route1", type: :heavy_rail, long_name: "Red Line")
      route2 = build(:route, id: "route2", type: :heavy_rail, long_name: "Blue Line")
      route3 = build(:route, id: "route3", type: :ferry, long_name: "Quincy Ferry")
      route4 = build(:route, id: "route4", type: :bus, long_name: "1 Bus")

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: [route1, route2, route3, route4] |> Map.new(&{&1.id, &1}),
          route_patterns: %{},
          stops: [stop] |> Map.new(&{&1.id, &1}),
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      route1_id = route1.id
      route2_id = route2.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route_type: 1}
          ]
        )

      assert [
               %Combination{route: ^route1_id},
               %Combination{route: ^route2_id}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters identical combinations" do
      stop = build(:stop, parent_station_id: nil)
      child_stop = build(:stop, parent_station_id: stop.id)
      route = build(:route, type: :heavy_rail, long_name: "Red Line")

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: %{},
          stops: [stop, child_stop] |> Map.new(&{&1.id, &1}),
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      route_id = route.id
      stop_id = stop.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, stop: stop.id},
            %InformedEntity{route: route_id, stop: child_stop.id}
          ]
        )

      assert [
               %Combination{route: ^route_id, stop: ^stop_id, direction: 0},
               %Combination{route: ^route_id, stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters combinations covered by another stop wildcard" do
      stop = build(:stop, parent_station_id: nil)
      child_stop = build(:stop, parent_station_id: stop.id)
      route = build(:route, type: :heavy_rail, long_name: "Red Line")

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: %{},
          stops: [stop, child_stop] |> Map.new(&{&1.id, &1}),
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      route_id = route.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: route_id, stop: nil},
            %InformedEntity{route: route_id, stop: stop.id}
          ]
        )

      assert [
               %Combination{route: ^route_id, stop: nil, direction: 0},
               %Combination{route: ^route_id, stop: nil, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters combinations covered by another route wildcard" do
      stop = build(:stop, parent_station_id: nil)
      child_stop = build(:stop, parent_station_id: stop.id)
      route = build(:route, type: :heavy_rail, long_name: "Red Line")

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: %{},
          stops: [stop, child_stop] |> Map.new(&{&1.id, &1}),
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      route_id = route.id
      stop_id = stop.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: nil, stop: stop.id},
            %InformedEntity{route: route_id, stop: stop.id}
          ]
        )

      assert [
               %Combination{route: nil, stop: ^stop_id, direction: 0},
               %Combination{route: nil, stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end

    test "filters combinations covered by another trip wildcard" do
      stop = build(:stop, parent_station_id: nil)
      child_stop = build(:stop, parent_station_id: stop.id)
      route = build(:route, type: :heavy_rail, long_name: "Red Line")
      trip = build(:trip, route_id: route.id, stop_ids: [child_stop.id])

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: [route] |> Map.new(&{&1.id, &1}),
          route_patterns: %{},
          stops: [stop, child_stop] |> Map.new(&{&1.id, &1}),
          trips: %{}
        }
      end)

      global = GlobalDataCache.get_data()

      route_id = route.id
      stop_id = stop.id
      trip_id = trip.id

      alert =
        build(:alert,
          cause: :maintenance,
          effect: :suspension,
          informed_entity: [
            %InformedEntity{route: nil, stop: stop.id, trip: nil},
            %InformedEntity{route: route_id, stop: stop.id, trip: trip_id, direction_id: 1}
          ]
        )

      assert [
               %Combination{route: nil, stop: ^stop_id, direction: 0},
               %Combination{route: nil, stop: ^stop_id, direction: 1}
             ] =
               SummaryEntityBuilder.relevant_combinations(alert, global.stops, global)
               |> Enum.sort_by(&{&1.route, &1.stop, &1.trip, &1.direction})
    end
  end

  describe "dedup_summaries/1" do
    test "removes duplicate summaries" do
      assert [
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop1",
                 trip_id: nil,
                 direction_id: nil,
                 summary: "identical summary"
               },
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop2",
                 trip_id: nil,
                 direction_id: 0,
                 summary: "different summary 1"
               },
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop2",
                 trip_id: nil,
                 direction_id: 1,
                 summary: "different summary 2"
               },
               %SummaryEntity{
                 alert_id: "alert",
                 route_id: "route",
                 stop_id: "stop3",
                 trip_id: nil,
                 direction_id: nil,
                 summary: "nil direction summary"
               }
             ] =
               SummaryEntityBuilder.dedup_summaries([
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop1",
                   trip_id: nil,
                   direction_id: 0,
                   summary: "identical summary"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop1",
                   trip_id: nil,
                   direction_id: 1,
                   summary: "identical summary"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop2",
                   trip_id: nil,
                   direction_id: 0,
                   summary: "different summary 1"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop2",
                   trip_id: nil,
                   direction_id: 1,
                   summary: "different summary 2"
                 },
                 %SummaryEntity{
                   alert_id: "alert",
                   route_id: "route",
                   stop_id: "stop3",
                   trip_id: nil,
                   direction_id: nil,
                   summary: "nil direction summary"
                 }
               ])
    end
  end
end

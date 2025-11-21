defmodule MBTAV3API.AlertTest do
  use ExUnit.Case

  import Mox
  import MobileAppBackend.Factory

  alias MBTAV3API.Alert.InformedEntity
  alias MBTAV3API.{Alert, JsonApi}
  alias MobileAppBackend.GlobalDataCache
  import Test.Support.Sigils

  setup :verify_on_exit!

  describe "active?/1" do
    test "true if in single active period" do
      assert Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:44:04],
                     end: ~B[2024-02-12 10:44:04]
                   }
                 ]
               },
               ~B[2024-02-12 09:44:28]
             )
    end

    test "false if outside single active period" do
      refute Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:45:04],
                     end: ~B[2024-02-12 09:45:10]
                   }
                 ]
               },
               ~B[2024-02-12 09:45:18]
             )
    end

    test "true if inside one of many active periods" do
      assert Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:00:00],
                     end: ~B[2024-02-12 10:00:00]
                   },
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 11:00:00],
                     end: ~B[2024-02-12 12:00:00]
                   }
                 ]
               },
               ~B[2024-02-12 11:22:33]
             )
    end

    test "false if outside each of many active periods" do
      refute Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:00:00],
                     end: ~B[2024-02-12 10:00:00]
                   },
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 11:00:00],
                     end: ~B[2024-02-12 12:00:00]
                   }
                 ]
               },
               ~B[2024-02-12 10:20:30]
             )
    end
  end

  test "parse!/1" do
    assert Alert.parse!(%JsonApi.Item{
             id: "553407",
             attributes: %{
               "active_period" => [
                 %{"start" => "2024-02-12T11:49:00-05:00", "end" => "2024-02-12T14:26:40-05:00"}
               ],
               "cause" => "FIRE",
               "description" => "Description",
               "duration_certainty" => "ESTIMATED",
               "effect" => "DELAY",
               "header" => "Header",
               "informed_entity" => [
                 %{"activities" => ["BOARD", "EXIT", "RIDE"], "route" => "39", "route_type" => 3}
               ],
               "lifecycle" => "NEW",
               "severity" => 7,
               "updated_at" => "2024-02-12T11:49:00-05:00"
             }
           }) == %Alert{
             id: "553407",
             active_period: [
               %Alert.ActivePeriod{start: ~B[2024-02-12 11:49:00], end: ~B[2024-02-12 14:26:40]}
             ],
             cause: :fire,
             description: "Description",
             duration_certainty: :estimated,
             effect: :delay,
             header: "Header",
             informed_entity: [
               %Alert.InformedEntity{
                 activities: [:board, :exit, :ride],
                 route: "39",
                 route_type: :bus
               }
             ],
             lifecycle: :new,
             severity: 7,
             updated_at: ~B[2024-02-12 11:49:00]
           }
  end

  test "unexpected enum values fall back" do
    assert Alert.parse!(%JsonApi.Item{
             id: "553407",
             attributes: %{
               "active_period" => [
                 %{"start" => "2024-02-12T11:49:00-05:00", "end" => "2024-02-12T14:26:40-05:00"}
               ],
               "cause" => "ALIENS",
               "description" => "Description",
               "duration_certainty" => "BEYOND_MORTAL_COMPREHENSION",
               "effect" => "TELEPORTATION",
               "header" => "Header",
               "informed_entity" => [
                 %{"activities" => ["BOARD", "EXIT", "RIDE"], "route" => "39", "route_type" => 3}
               ],
               "lifecycle" => "NEW",
               "updated_at" => "2024-02-12T11:49:00-05:00"
             }
           }) == %Alert{
             id: "553407",
             active_period: [
               %Alert.ActivePeriod{start: ~B[2024-02-12 11:49:00], end: ~B[2024-02-12 14:26:40]}
             ],
             cause: :unknown_cause,
             description: "Description",
             duration_certainty: :unknown,
             effect: :unknown_effect,
             header: "Header",
             informed_entity: [
               %Alert.InformedEntity{
                 activities: [:board, :exit, :ride],
                 route: "39",
                 route_type: :bus
               }
             ],
             lifecycle: :new,
             updated_at: ~B[2024-02-12 11:49:00]
           }
  end

  test "collapses adjacent active periods" do
    assert Alert.parse!(%JsonApi.Item{
             id: "630418",
             attributes: %{
               "active_period" => [
                 %{"start" => "2025-03-28T03:00:00-04:00", "end" => "2025-03-29T02:59:00-04:00"},
                 %{"start" => "2025-03-29T03:00:00-04:00", "end" => "2025-03-30T02:59:00-04:00"},
                 %{"start" => "2025-03-30T03:00:00-04:00", "end" => "2025-03-31T02:59:00-04:00"},
                 %{"start" => "2025-03-31T03:00:00-04:00", "end" => "2025-04-01T02:59:00-04:00"},
                 %{"start" => "2025-04-01T03:00:00-04:00", "end" => "2025-04-02T02:59:00-04:00"},
                 %{"start" => "2025-04-02T03:00:00-04:00", "end" => "2025-04-03T02:59:00-04:00"},
                 %{"start" => "2025-04-03T03:00:00-04:00", "end" => "2025-04-04T02:59:00-04:00"},
                 %{"start" => "2025-04-04T03:00:00-04:00", "end" => "2025-04-05T02:59:00-04:00"},
                 %{"start" => "2025-04-05T03:00:00-04:00", "end" => "2025-04-06T02:59:00-04:00"},
                 %{"start" => "2025-04-06T03:00:00-04:00", "end" => "2025-04-07T02:59:00-04:00"},
                 %{"start" => "2025-04-07T03:00:00-04:00", "end" => "2025-04-08T02:59:00-04:00"},
                 %{"start" => "2025-04-08T03:00:00-04:00", "end" => "2025-04-09T02:59:00-04:00"},
                 %{"start" => "2025-04-09T03:00:00-04:00", "end" => "2025-04-10T02:59:00-04:00"},
                 %{"start" => "2025-04-10T03:00:00-04:00", "end" => "2025-04-11T02:59:00-04:00"},
                 %{"start" => "2025-04-11T03:00:00-04:00", "end" => "2025-04-12T02:59:00-04:00"},
                 %{"start" => "2025-04-12T03:00:00-04:00", "end" => "2025-04-13T02:59:00-04:00"},
                 %{"start" => "2025-04-13T03:00:00-04:00", "end" => "2025-04-14T02:59:00-04:00"},
                 %{"start" => "2025-04-14T03:00:00-04:00", "end" => "2025-04-15T02:59:00-04:00"},
                 %{"start" => "2025-04-15T03:00:00-04:00", "end" => "2025-04-16T02:59:00-04:00"},
                 %{"start" => "2025-04-16T03:00:00-04:00", "end" => "2025-04-17T02:59:00-04:00"},
                 %{"start" => "2025-04-17T03:00:00-04:00", "end" => "2025-04-18T02:59:00-04:00"},
                 %{"start" => "2025-04-18T03:00:00-04:00", "end" => "2025-04-19T02:59:00-04:00"},
                 %{"start" => "2025-04-19T03:00:00-04:00", "end" => "2025-04-20T02:59:00-04:00"},
                 %{"start" => "2025-04-20T03:00:00-04:00", "end" => "2025-04-21T02:59:00-04:00"},
                 %{"start" => "2025-04-21T03:00:00-04:00", "end" => "2025-04-22T02:59:00-04:00"},
                 %{"start" => "2025-04-22T03:00:00-04:00", "end" => "2025-04-23T02:59:00-04:00"},
                 %{"start" => "2025-04-23T03:00:00-04:00", "end" => "2025-04-24T02:59:00-04:00"},
                 %{"start" => "2025-04-24T03:00:00-04:00", "end" => "2025-04-25T02:59:00-04:00"},
                 %{"start" => "2025-04-25T03:00:00-04:00", "end" => "2025-04-26T02:59:00-04:00"},
                 %{"start" => "2025-04-26T03:00:00-04:00", "end" => "2025-04-27T02:59:00-04:00"},
                 %{"start" => "2025-04-27T03:00:00-04:00", "end" => "2025-04-28T02:59:00-04:00"},
                 %{"start" => "2025-04-28T03:00:00-04:00", "end" => "2025-04-29T02:59:00-04:00"},
                 %{"start" => "2025-04-29T03:00:00-04:00", "end" => "2025-04-30T02:59:00-04:00"},
                 %{"start" => "2025-04-30T03:00:00-04:00", "end" => "2025-05-01T02:59:00-04:00"},
                 %{"start" => "2025-05-01T03:00:00-04:00", "end" => "2025-05-02T02:59:00-04:00"},
                 %{"start" => "2025-05-02T03:00:00-04:00", "end" => "2025-05-03T02:59:00-04:00"},
                 %{"start" => "2025-05-03T03:00:00-04:00", "end" => "2025-05-04T02:59:00-04:00"},
                 %{"start" => "2025-05-04T03:00:00-04:00", "end" => "2025-05-05T02:59:00-04:00"},
                 %{"start" => "2025-05-05T03:00:00-04:00", "end" => "2025-05-06T02:59:00-04:00"},
                 %{"start" => "2025-05-06T03:00:00-04:00", "end" => "2025-05-07T02:59:00-04:00"},
                 %{"start" => "2025-05-07T03:00:00-04:00", "end" => "2025-05-08T02:59:00-04:00"},
                 %{"start" => "2025-05-08T03:00:00-04:00", "end" => "2025-05-09T02:59:00-04:00"},
                 %{"start" => "2025-05-09T03:00:00-04:00", "end" => "2025-05-10T02:59:00-04:00"},
                 %{"start" => "2025-05-10T03:00:00-04:00", "end" => "2025-05-11T02:59:00-04:00"},
                 %{"start" => "2025-05-11T03:00:00-04:00", "end" => "2025-05-12T02:59:00-04:00"}
               ],
               "cause" => "CONSTRUCTION",
               "description" => "Description",
               "duration_certainty" => "KNOWN",
               "effect" => "STOP_CLOSURE",
               "header" => "Header",
               "informed_entity" => [
                 %{
                   "activities" => ["BOARD", "EXIT"],
                   "route" => "47",
                   "route_type" => 3,
                   "stop" => "1123"
                 }
               ],
               "lifecycle" => "NEW",
               "severity" => 5,
               "updated_at" => "2025-03-17T15:17:11-04:00"
             }
           }) == %Alert{
             id: "630418",
             active_period: [
               %Alert.ActivePeriod{start: ~B[2025-03-28 03:00:00], end: ~B[2025-05-12 02:59:00]}
             ],
             cause: :construction,
             description: "Description",
             duration_certainty: :known,
             effect: :stop_closure,
             header: "Header",
             informed_entity: [
               %Alert.InformedEntity{
                 activities: [:board, :exit],
                 route: "47",
                 route_type: :bus,
                 stop: "1123"
               }
             ],
             lifecycle: :new,
             severity: 5,
             updated_at: ~B[2025-03-17 15:17:11]
           }
  end

  test "alert significance is set properly" do
    for effect <- [
          :access_issue,
          :additional_service,
          :amber_alert,
          :bike_issue,
          :cancellation,
          :delay,
          :detour,
          :dock_closure,
          :dock_issue,
          :elevator_closure,
          :escalator_closure,
          :extra_service,
          :facility_issue,
          :modified_service,
          :no_service,
          :other_effect,
          :parking_closure,
          :parking_issue,
          :policy_change,
          :schedule_change,
          :service_change,
          :shuttle,
          :snow_route,
          :station_closure,
          :station_issue,
          :stop_closure,
          :stop_move,
          :stop_moved,
          :stop_shoveling,
          :summary,
          :suspension,
          :track_change,
          :unknown_effect
        ] do
      inherently_stop_specific =
        effect in [:dock_closure, :dock_issue, :station_closure, :station_issue, :stop_closure]

      specified_stops_options = if inherently_stop_specific, do: [true], else: [false, true]

      for specified_stops <- specified_stops_options do
        alert =
          build(:alert,
            effect: effect,
            severity: 1,
            informed_entity: [%InformedEntity{stop: if(specified_stops, do: "stop")}]
          )

        expected_significance =
          case effect do
            :detour -> if specified_stops, do: :major, else: :secondary
            :dock_closure -> :major
            :elevator_closure -> :accessibility
            :service_change -> :secondary
            :shuttle -> :major
            :snow_route -> if specified_stops, do: :major, else: :secondary
            :station_closure -> :major
            :stop_closure -> :major
            :suspension -> :major
            :track_change -> :minor
            _ -> nil
          end

        assert Alert.significance(alert) == expected_significance,
               "significance for effect #{effect} #{if specified_stops, do: "with", else: "without"} specified stops"
      end
    end
  end

  test "alert significance for delay alerts" do
    subway_delay_severe =
      build(:alert,
        effect: :delay,
        severity: 10,
        informed_entity: [%InformedEntity{route_type: :light_rail, stop: "stop"}]
      )

    cr_delay_severe =
      build(:alert,
        effect: :delay,
        severity: 10,
        informed_entity: [%InformedEntity{route_type: :commuter_rail, stop: "stop"}]
      )

    ferry_delay_severe =
      build(:alert,
        effect: :delay,
        severity: 10,
        informed_entity: [%InformedEntity{route_type: :ferry, stop: "stop"}]
      )

    subway_delay_not_severe =
      build(:alert,
        effect: :delay,
        severity: 0,
        informed_entity: [%InformedEntity{route_type: :light_rail, stop: "stop"}]
      )

    bus_delay_severe =
      build(:alert,
        effect: :delay,
        severity: 10,
        informed_entity: [%InformedEntity{route_type: :bus, stop: "stop"}]
      )

    single_tracking_delay_info =
      build(:alert,
        cause: :single_tracking,
        effect: :delay,
        severity: 1
      )

    assert Alert.significance(subway_delay_severe) == :minor
    assert Alert.significance(cr_delay_severe) == :minor
    assert Alert.significance(ferry_delay_severe) == :minor
    assert Alert.significance(single_tracking_delay_info) == :minor
    assert Alert.significance(subway_delay_not_severe) == nil
    assert Alert.significance(bus_delay_severe) == nil
  end

  test "downstreamAlerts returns alerts for first downstream alerting stop" do
    route = build(:route)
    target_stop = build(:stop)
    stop_with_board_alert = build(:stop)
    [first_stop_with_ride_alert, second_stop_with_ride_alert] = build_pair(:stop)

    alert_ride_target_stop =
      build(:alert,
        effect: :service_change,
        informed_entity: [
          %InformedEntity{
            activities: [:ride],
            direction_id: 0,
            route: route.id,
            stop: target_stop.id
          }
        ]
      )

    alert_board =
      build(:alert,
        effect: :service_change,
        informed_entity: [
          %InformedEntity{
            activities: [:board],
            direction_id: 0,
            route: route.id,
            stop: stop_with_board_alert.id
          }
        ]
      )

    first_ride_alert =
      build(:alert,
        effect: :service_change,
        informed_entity: [
          %InformedEntity{
            activities: [:ride],
            route: route.id,
            stop: first_stop_with_ride_alert.id
          }
        ]
      )

    second_ride_alert =
      build(:alert,
        effect: :service_change,
        informed_entity: [
          %InformedEntity{
            activities: [:ride],
            route: route.id,
            stop: second_stop_with_ride_alert.id
          }
        ]
      )

    trip =
      build(:trip,
        direction_id: 0,
        route_id: route.id,
        stop_ids: [
          target_stop.id,
          stop_with_board_alert.id,
          first_stop_with_ride_alert.id,
          second_stop_with_ride_alert.id
        ]
      )

    downstream_alerts =
      Alert.downstream_alerts(
        [alert_ride_target_stop, alert_board, first_ride_alert, second_ride_alert],
        trip,
        [target_stop.id]
      )

    assert downstream_alerts == [first_ride_alert]
  end

  test "downstreamAlerts excludes alerts affecting the target stop" do
    route = build(:route)
    target_stop = build(:stop)
    [downstream_stop1, downstream_stop2] = build_pair(:stop)

    alert_all_stops =
      build(:alert,
        effect: :service_change,
        informed_entity: [
          %InformedEntity{
            activities: [:board, :ride],
            direction_id: 0,
            route: route.id,
            stop: target_stop.id
          },
          %InformedEntity{
            activities: [:board, :ride],
            direction_id: 0,
            route: route.id,
            stop: downstream_stop1.id
          },
          %InformedEntity{
            activities: [:board, :ride],
            direction_id: 0,
            route: route.id,
            stop: downstream_stop2.id
          }
        ]
      )

    alert_downstream2_only =
      build(:alert,
        effect: :service_change,
        informed_entity: [
          %InformedEntity{
            activities: [:ride],
            direction_id: 0,
            route: route.id,
            stop: downstream_stop2.id
          }
        ]
      )

    trip =
      build(:trip,
        direction_id: 0,
        route_id: route.id,
        stop_ids: [target_stop.id, downstream_stop1.id, downstream_stop2.id]
      )

    downstream_alerts =
      Alert.downstream_alerts([alert_all_stops, alert_downstream2_only], trip, [target_stop.id])

    assert downstream_alerts == [alert_downstream2_only]
  end

  test "downstreamAlerts ignores alert without stops specified" do
    route = build(:route)
    [target_stop, next_stop] = build_pair(:stop)

    alert =
      build(:alert,
        effect: :service_change,
        informed_entity: [%InformedEntity{activities: [:board], route: route.id}]
      )

    trip =
      build(:trip, direction_id: 0, route_id: route.id, stop_ids: [target_stop.id, next_stop.id])

    downstream_alerts = Alert.downstream_alerts([alert], trip, [target_stop.id])
    assert downstream_alerts == []
  end

  test "alertsDownstreamForPatterns returns alert for downstream stop" do
    Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
    global_data = GlobalDataCache.get_data()

    route_pattern_ashmont = global_data.route_patterns["Red-1-0"]
    route_pattern_braintree = global_data.route_patterns["Red-3-0"]
    route_pattern_alewife = global_data.route_patterns["Red-3-1"]

    shawmut_shuttle_alert =
      build(:alert,
        effect: :shuttle,
        informed_entity: [
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "70091"},
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "70092"}
        ]
      )

    ashmont_shuttle_alert =
      build(:alert,
        effect: :shuttle,
        informed_entity: [
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "70093"},
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "70094"}
        ]
      )

    alewife_shuttle_alert =
      build(:alert,
        effect: :shuttle,
        informed_entity: [
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "70061"},
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "Alewife-01"},
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "Alewife-02"}
        ]
      )

    park_shuttle_alert =
      build(:alert,
        effect: :shuttle,
        informed_entity: [
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "70075"},
          %InformedEntity{activities: [:board, :ride], route: "Red", stop: "70076"}
        ]
      )

    southbound_downstream_alerts =
      Alert.alerts_downstream_for_patterns(
        [ashmont_shuttle_alert, shawmut_shuttle_alert, park_shuttle_alert, alewife_shuttle_alert],
        [route_pattern_ashmont, route_pattern_braintree],
        ["place-pktrm", "70075", "70076"],
        global_data.trips
      )

    assert southbound_downstream_alerts == [shawmut_shuttle_alert]

    northbound_downstream_alerts =
      Alert.alerts_downstream_for_patterns(
        [ashmont_shuttle_alert, shawmut_shuttle_alert, park_shuttle_alert, alewife_shuttle_alert],
        [route_pattern_alewife],
        ["place-pktrm", "70075", "70076"],
        global_data.trips
      )

    assert northbound_downstream_alerts == [alewife_shuttle_alert]
  end
end

defmodule MobileAppBackend.Alerts.AlertSummaryTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  require Jason.Sigil
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.Direction
  alias MobileAppBackend.Alerts.AlertSummary.Location
  alias MobileAppBackend.Alerts.AlertSummary.Recurrence

  alias MobileAppBackend.Alerts.AlertSummary.Timeframe

  alias MobileAppBackend.Alerts.AlertSummary.TripShuttle

  alias MobileAppBackend.Alerts.AlertSummary.TripSpecific

  alias MobileAppBackend.GlobalDataCache

  setup :verify_on_exit!

  setup do
    %{now: DateTime.now!("America/New_York")}
  end

  describe "Direction" do
    test "basic case gets correct values" do
      route =
        build(:route,
          direction_names: ["Wrong Name", "Right Name"],
          direction_destinations: ["Wrong Destination", "Right Destination"]
        )

      direction = Direction.new(1, route)
      assert %Direction{name: "Right Name", destination: "Right Destination", id: 1} = direction
    end

    test "special cases get correct values" do
      green_b =
        build(:route,
          id: "Green-B",
          direction_names: ["West", "East"],
          direction_destinations: ["Boston College", "Government Center"]
        )

      red =
        build(:route,
          id: "Red",
          direction_names: ["South", "North"],
          direction_destinations: ["Ashmont/Braintree", "Alewife"]
        )

      assert %Direction{name: "West", destination: "Copley & West"} =
               Direction.new(0, green_b, "place-armnl", [
                 "place-gover",
                 "place-pktrm",
                 "place-armnl",
                 "place-hymnl",
                 "place-kencl",
                 "place-lake"
               ])

      assert %Direction{name: "East", destination: "Gov Ctr & North"} =
               Direction.new(1, green_b, "place-armnl", [
                 "place-lake",
                 "place-kencl",
                 "place-hymnl",
                 "place-armnl",
                 "place-pktrm",
                 "place-gover"
               ])

      assert %Direction{name: "South", destination: "Ashmont"} =
               Direction.new(0, red, "place-shmnl", [
                 "place-alfcl",
                 "place-jfk",
                 "place-shmnl",
                 "place-asmnl"
               ])

      assert %Direction{name: "North", destination: "Alewife"} =
               Direction.new(1, red, "place-shmnl", [
                 "place-asmnl",
                 "place-shmnl",
                 "place-jfk",
                 "place-alfcl"
               ])
    end

    test "both direction helper provides correct values" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()
      stop = global.stops["place-bckhl"]
      route = global.routes["Green-E"]

      trip1 =
        build(:trip,
          route_pattern_id: "rp1",
          stop_ids: ["place-mdftf", "place-armnl", "place-bckhl", "place-hsmnl"]
        )

      route_pattern1 =
        build(:route_pattern,
          route_id: route.id,
          id: "rp1",
          representative_trip_id: trip1.id,
          direction_id: 0,
          typicality: :atypical
        )

      route_pattern2 = global.route_patterns["Green-E-886-0"]
      route_pattern3 = global.route_patterns["Green-E-886-1"]

      global =
        global
        |> put_in([:trips, trip1.id], trip1)
        |> put_in([:route_patterns, route_pattern1.id], route_pattern1)

      patterns = [route_pattern1, route_pattern2, route_pattern3]
      directions = Direction.get_directions(global, stop, route, patterns)

      assert [%Direction{destination: "Heath Street"}, %Direction{destination: "Park St & North"}] =
               directions
    end

    test "get_directions_for_line at different stops along the GL" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()
      south_st = global.stops["place-sougr"]
      kenmore = global.stops["place-kencl"]
      hynes = global.stops["place-hymnl"]
      gov = global.stops["place-gover"]
      magoun = global.stops["place-mgngl"]
      route_pattern_b1 = global.route_patterns["Green-B-812-0"]
      route_pattern_b2 = global.route_patterns["Green-B-812-1"]
      route_pattern_c1 = global.route_patterns["Green-C-832-0"]
      route_pattern_c2 = global.route_patterns["Green-C-832-1"]
      route_pattern_e1 = global.route_patterns["Green-E-886-0"]
      route_pattern_e2 = global.route_patterns["Green-E-886-1"]

      assert [
               %Direction{destination: "Boston College"},
               %Direction{destination: "Park St & North"}
             ] =
               Direction.get_directions_for_line(global, south_st, [
                 route_pattern_b1,
                 route_pattern_b2
               ])

      assert [%Direction{destination: nil}, %Direction{destination: "Park St & North"}] =
               Direction.get_directions_for_line(global, kenmore, [
                 route_pattern_b1,
                 route_pattern_b2,
                 route_pattern_c1,
                 route_pattern_c2
               ])

      assert [
               %Direction{destination: "Kenmore & West"},
               %Direction{destination: "Park St & North"}
             ] =
               Direction.get_directions_for_line(global, hynes, [
                 route_pattern_b1,
                 route_pattern_b2,
                 route_pattern_c1,
                 route_pattern_c2
               ])

      assert [
               %Direction{destination: "Copley & West"},
               %Direction{destination: "North Station & North"}
             ] =
               Direction.get_directions_for_line(global, gov, [
                 route_pattern_b1,
                 route_pattern_b2,
                 route_pattern_c1,
                 route_pattern_c2,
                 route_pattern_e1,
                 route_pattern_e2
               ])

      assert [%Direction{destination: "Copley & West"}, %Direction{destination: "Medford/Tufts"}] =
               Direction.get_directions_for_line(global, magoun, [
                 route_pattern_e1,
                 route_pattern_e2
               ])
    end
  end

  describe "serialization" do
    defp json_round_trip(value), do: Jason.decode!(Jason.encode_to_iodata!(value), keys: :atoms!)

    test "can serialize full standard summary" do
      assert json_round_trip(%AlertSummary.Standard{
               effect: :station_closure,
               location: %AlertSummary.Location.SingleStop{stop_name: "Lechmere"},
               timeframe: %AlertSummary.Timeframe.Tomorrow{},
               recurrence: %AlertSummary.Recurrence.SomeDays{
                 ending: %AlertSummary.Timeframe.LaterDate{time: ~B[2026-01-16 10:31:00]}
               },
               is_update: true
             }) ==
               %{
                 type: "standard",
                 effect: "station_closure",
                 location: %{
                   type: "single_stop",
                   stop_name: "Lechmere"
                 },
                 timeframe: %{type: "tomorrow"},
                 recurrence: %{
                   type: "some_days",
                   ending: %{type: "later_date", time: "2026-01-16T10:31:00-05:00"}
                 },
                 is_update: true
               }
    end

    test "can serialize all clear summary" do
      assert json_round_trip(%AlertSummary.AllClear{
               location: %AlertSummary.Location.SuccessiveStops{
                 start_stop_name: "Lechmere",
                 end_stop_name: "Government Center"
               }
             }) == %{
               type: "all_clear",
               location: %{
                 type: "successive_stops",
                 start_stop_name: "Lechmere",
                 end_stop_name: "Government Center"
               }
             }
    end

    test "can serialize trip specific summary" do
      assert json_round_trip(%AlertSummary.TripSpecific{
               trip_identity: %AlertSummary.TripSpecific.TripFrom{
                 trip_time: ~B[2026-03-06 15:19:00],
                 stop_name: "North Station"
               },
               effect: :suspension,
               effect_stops: nil,
               is_today: true,
               cause: :holiday,
               recurrence: %AlertSummary.Recurrence.Daily{
                 ending: %AlertSummary.Timeframe.LaterDate{time: ~B[2026-03-10 14:28:00]}
               }
             }) == %{
               type: "trip_specific",
               trip_identity: %{
                 type: "trip_from",
                 trip_time: "2026-03-06T15:19:00-05:00",
                 stop_name: "North Station"
               },
               effect: "suspension",
               effect_stops: nil,
               is_today: true,
               cause: "holiday",
               recurrence: %{
                 type: "daily",
                 ending: %{type: "later_date", time: "2026-03-10T14:28:00-04:00"}
               }
             }
    end

    test "can serialize trip shuttle summary" do
      assert json_round_trip(%AlertSummary.TripShuttle{
               trip_identity: %AlertSummary.TripShuttle.SingleTrip{
                 trip_time: ~B[2026-03-06 15:21:00],
                 route_type: :commuter_rail
               },
               is_today: true,
               current_stop_name: "Ruggles",
               end_stop_name: "Forest Hills",
               recurrence: nil
             }) == %{
               type: "trip_shuttle",
               trip_identity: %{
                 type: "single_trip",
                 trip_time: "2026-03-06T15:21:00-05:00",
                 route_type: "commuter_rail"
               },
               is_today: true,
               current_stop_name: "Ruggles",
               end_stop_name: "Forest Hills",
               recurrence: nil
             }
    end

    test "can serialize all locations" do
      assert json_round_trip(%AlertSummary.Location.DirectionToStop{
               direction: %Direction{name: "East", destination: "Union Square", id: 1},
               end_stop_name: "Lechmere"
             }) == %{
               type: "direction_to_stop",
               direction: %{name: "East", destination: "Union Square", id: 1},
               end_stop_name: "Lechmere"
             }

      assert json_round_trip(%AlertSummary.Location.SingleStop{stop_name: "Lechmere"}) == %{
               type: "single_stop",
               stop_name: "Lechmere"
             }

      assert json_round_trip(%AlertSummary.Location.StopToDirection{
               start_stop_name: "Lechmere",
               direction: %Direction{name: "West", destination: "Copley & West", id: 0}
             }) == %{
               type: "stop_to_direction",
               start_stop_name: "Lechmere",
               direction: %{name: "West", destination: "Copley & West", id: 0}
             }

      assert json_round_trip(%AlertSummary.Location.SuccessiveStops{
               start_stop_name: "Lechmere",
               end_stop_name: "North Station"
             }) == %{
               type: "successive_stops",
               start_stop_name: "Lechmere",
               end_stop_name: "North Station"
             }
    end

    test "can serialize all timeframes" do
      assert json_round_trip(%AlertSummary.Timeframe.EndOfService{}) == %{type: "end_of_service"}
      assert json_round_trip(%AlertSummary.Timeframe.Tomorrow{}) == %{type: "tomorrow"}

      assert json_round_trip(%AlertSummary.Timeframe.LaterDate{time: ~B[2025-12-30 16:11:00]}) ==
               %{type: "later_date", time: "2025-12-30T16:11:00-05:00"}

      assert json_round_trip(%AlertSummary.Timeframe.ThisWeek{time: ~B[2025-12-30 16:12:00]}) ==
               %{type: "this_week", time: "2025-12-30T16:12:00-05:00"}

      assert json_round_trip(%AlertSummary.Timeframe.Time{time: ~B[2025-12-30 16:12:00]}) == %{
               type: "time",
               time: "2025-12-30T16:12:00-05:00"
             }

      assert json_round_trip(%AlertSummary.Timeframe.StartingTomorrow{}) == %{
               type: "starting_tomorrow"
             }

      assert json_round_trip(%AlertSummary.Timeframe.StartingLaterToday{
               time: ~B[2026-01-15 13:03:00]
             }) == %{
               type: "starting_later_today",
               time: "2026-01-15T13:03:00-05:00"
             }

      assert json_round_trip(%AlertSummary.Timeframe.TimeRange{
               start_time: %AlertSummary.Timeframe.TimeRange.Time{time: ~B[2026-01-23 15:35:00]},
               end_time: %AlertSummary.Timeframe.TimeRange.EndOfService{}
             }) == %{
               type: "time_range",
               start_time: %{type: "time", time: "2026-01-23T15:35:00-05:00"},
               end_time: %{type: "end_of_service"}
             }
    end

    test "can serialize all trip identities" do
      assert json_round_trip(%AlertSummary.TripSpecific.TripFrom{
               trip_time: ~B[2026-03-06 15:25:00],
               stop_name: "Ruggles"
             }) == %{
               type: "trip_from",
               trip_time: "2026-03-06T15:25:00-05:00",
               stop_name: "Ruggles"
             }

      assert json_round_trip(%AlertSummary.TripSpecific.TripTo{
               trip_time: ~B[2026-03-06 15:25:00],
               headsign: "South Station"
             }) == %{
               type: "trip_to",
               trip_time: "2026-03-06T15:25:00-05:00",
               headsign: "South Station"
             }

      assert json_round_trip(%AlertSummary.TripSpecific.MultipleTrips{}) == %{
               type: "multiple_trips"
             }
    end
  end

  describe "summarizing/7" do
    test "summary with until further notice timeframe", %{now: now} do
      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(now, -1, :hour),
              end: nil
            }
          ],
          duration_certainty: :known
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with later today timeframe", %{now: now} do
      end_time = DateTime.add(now, 1, :hour)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.Time{time: ^end_time}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with end of service timeframe", %{now: now} do
      tomorrow = Util.datetime_to_gtfs(now) |> Date.add(1)
      end_time = DateTime.new!(tomorrow, ~T[02:59:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.EndOfService{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with alt end of service timeframe", %{now: now} do
      tomorrow = Util.datetime_to_gtfs(now) |> Date.add(1)
      end_time = DateTime.new!(tomorrow, ~T[03:00:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.EndOfService{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with tomorrow timeframe", %{now: now} do
      # Set to tomorrow's end of service, with a date of 2 days from now
      tomorrow = Util.datetime_to_gtfs(now) |> Date.add(2)
      end_time = DateTime.new!(tomorrow, ~T[03:00:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.Tomorrow{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with this week timeframe" do
      # Fixed time so we can have a specific day of the week (wed)
      now = ~B[2025-04-02 09:00:00]
      saturday = Util.datetime_to_gtfs(now) |> Date.add(3)
      end_time = DateTime.new!(saturday, ~T[05:00:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.ThisWeek{time: ^end_time}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with later date timeframe" do
      # Fixed time so we can have a specific day of the week (wed)
      now = ~B[2025-04-02 09:00:00]
      monday = Util.datetime_to_gtfs(now) |> Date.add(5)
      end_time = DateTime.new!(monday, ~T[05:00:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.LaterDate{time: ^end_time}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with starting tomorrow timeframe" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, 23, :hour), end: nil}]
        )

      assert %AlertSummary.Standard{timeframe: %AlertSummary.Timeframe.StartingTomorrow{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with starting later today timeframe" do
      now = DateTime.now!("America/New_York")
      later_today = DateTime.add(now, 1, :hour)
      alert = build(:alert, active_period: [%Alert.ActivePeriod{start: later_today, end: nil}])

      assert %AlertSummary.Standard{
               timeframe: %AlertSummary.Timeframe.StartingLaterToday{time: ^later_today}
             } = AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with single stop", %{now: now} do
      stop = build(:stop, name: "Parent Name")
      child_stop = build(:stop, parent_station_id: stop.id)
      stop = put_in(stop.child_stop_ids, [child_stop.id])

      route = build(:route)
      pattern = build(:route_pattern, route_id: route.id, direction_id: 0)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity: [
            %Alert.InformedEntity{
              activities: ~w(board exit ride)a,
              route: route.id,
              stop: child_stop.id
            }
          ]
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.SingleStop{stop_name: "Parent Name"}
             } =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, nil, %{
                 routes: %{route.id => route},
                 stops: %{stop.id => stop, child_stop.id => child_stop}
               })
    end

    test "summary with successive stops", %{now: now} do
      first_stop = build(:stop, name: "First Stop")
      successive_stops = build_list(4, :stop)
      last_stop = build(:stop, name: "Last Stop")

      stops = [first_stop] ++ successive_stops ++ [last_stop]

      route = build(:route, type: :light_rail)
      trip = build(:trip, stop_ids: Enum.map(stops, & &1.id))

      pattern =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: trip.id
        )

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity:
            Enum.map(
              successive_stops ++ [last_stop],
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                stop: &1.id
              }
            )
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.SuccessiveStops{
                 start_stop_name: "Harvard Sq @ Garden St - Dawes Island",
                 end_stop_name: "Last Stop"
               }
             } =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, nil, %{
                 routes: %{route.id => route},
                 stops: Map.new(stops, &{&1.id, &1}),
                 trips: %{trip.id => trip}
               })
    end

    test "summary with successive bus stops", %{now: now} do
      first_stop = build(:stop, name: "First Stop")
      successive_stops = build_list(4, :stop)
      last_stop = build(:stop, name: "Last Stop")

      stops = [first_stop] ++ successive_stops ++ [last_stop]

      route = build(:route, type: :bus)
      trip = build(:trip, stop_ids: Enum.map(stops, & &1.id))

      pattern =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: trip.id
        )

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity:
            Enum.map(
              stops,
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                stop: &1.id
              }
            )
        )

      assert %AlertSummary.Standard{location: nil} =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, nil, %{
                 routes: %{route.id => route},
                 stops: Map.new(stops, &{&1.id, &1}),
                 trips: %{trip.id => trip}
               })
    end

    test "summary with branching stops ahead", %{now: now} do
      unaffected_stops = build_list(4, :stop)
      first_stop = build(:stop, name: "First Stop")
      trunk_stops = build_list(4, :stop)
      branch1_stops = build_list(4, :stop)
      branch2_stops = build_list(4, :stop)

      route =
        build(:route,
          type: :light_rail,
          direction_names: ["Inbound", "Outbound"],
          direction_destinations: ["A", "Z"]
        )

      trip1 =
        build(:trip,
          stop_ids:
            Enum.map(unaffected_stops ++ [first_stop] ++ trunk_stops ++ branch1_stops, & &1.id)
        )

      trip2 =
        build(:trip,
          stop_ids:
            Enum.map(unaffected_stops ++ [first_stop] ++ trunk_stops ++ branch2_stops, & &1.id)
        )

      branch1 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: trip1.id
        )

      branch2 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: trip2.id
        )

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity:
            Enum.map(
              [first_stop] ++ trunk_stops ++ branch1_stops ++ branch2_stops,
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                stop: &1.id
              }
            )
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.StopToDirection{
                 start_stop_name: "First Stop",
                 direction: %Direction{name: "Inbound", destination: "A", id: 0}
               }
             } =
               AlertSummary.summarizing(
                 alert,
                 hd(unaffected_stops).id,
                 0,
                 [branch1, branch2],
                 now,
                 nil,
                 %{
                   routes: %{route.id => route},
                   stops:
                     Map.new(
                       unaffected_stops ++
                         [first_stop] ++ trunk_stops ++ branch1_stops ++ branch2_stops,
                       &{&1.id, &1}
                     ),
                   trips: %{trip1.id => trip1, trip2.id => trip2}
                 }
               )
    end

    test "summary with branching stops behind", %{now: now} do
      unaffected_stops = build_list(4, :stop)
      last_stop = build(:stop, name: "Last Stop")
      trunk_stops = build_list(4, :stop)
      branch1_stops = build_list(4, :stop)
      branch2_stops = build_list(4, :stop)

      route =
        build(:route,
          type: :light_rail,
          direction_names: ["Inbound", "Outbound"],
          direction_destinations: ["A", "Z"]
        )

      trip1 =
        build(:trip,
          stop_ids:
            Enum.map(branch1_stops ++ trunk_stops ++ [last_stop] ++ unaffected_stops, & &1.id)
        )

      trip2 =
        build(:trip,
          stop_ids:
            Enum.map(branch2_stops ++ trunk_stops ++ [last_stop] ++ unaffected_stops, & &1.id)
        )

      branch1 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: trip1.id
        )

      branch2 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: trip2.id
        )

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity:
            Enum.map(
              [last_stop] ++ trunk_stops ++ branch1_stops ++ branch2_stops,
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                stop: &1.id
              }
            )
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.DirectionToStop{
                 direction: %Direction{name: "Outbound", destination: "Z", id: 1},
                 end_stop_name: "Last Stop"
               }
             } =
               AlertSummary.summarizing(
                 alert,
                 hd(unaffected_stops).id,
                 0,
                 [branch1, branch2],
                 now,
                 nil,
                 %{
                   routes: %{route.id => route},
                   stops:
                     Map.new(
                       unaffected_stops ++
                         [last_stop] ++ trunk_stops ++ branch1_stops ++ branch2_stops,
                       &{&1.id, &1}
                     ),
                   trips: %{trip1.id => trip1, trip2.id => trip2}
                 }
               )
    end

    test "summary with branching GL stops ahead", %{now: now} do
      kenmore = build(:stop, name: "Kenmore", child_stop_ids: ["70151", "71151"])
      blandford = build(:stop, name: "Blandford Street", child_stop_ids: ["70149"])
      saint_marys = build(:stop, name: "Saint Mary's Street", child_stop_ids: ["70211"])

      child_stops = [
        build(:stop, id: "70151", parent_station_id: kenmore.id),
        build(:stop, id: "71151", parent_station_id: kenmore.id),
        build(:stop, id: "70149", parent_station_id: blandford.id),
        build(:stop, id: "70211", parent_station_id: saint_marys.id)
      ]

      route =
        build(:route,
          type: :light_rail,
          line_id: "line-Green",
          direction_names: ["Westbound", "Eastbound"],
          direction_destinations: ["", "Park St & North"]
        )

      b_branch_trip = build(:trip, stop_ids: ["71151", "70149"])
      c_branch_trip = build(:trip, stop_ids: ["70151", "70211"])

      b_branch =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: b_branch_trip.id
        )

      c_branch =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: c_branch_trip.id
        )

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity:
            Enum.map(
              [kenmore, blandford, saint_marys | child_stops],
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                stop: &1.id
              }
            )
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.StopToDirection{
                 start_stop_name: "Kenmore",
                 direction: %Direction{name: "Westbound", destination: "", id: 0}
               }
             } =
               AlertSummary.summarizing(alert, kenmore.id, 0, [b_branch, c_branch], now, nil, %{
                 routes: %{route.id => route},
                 stops: Map.new([kenmore, blandford, saint_marys | child_stops], &{&1.id, &1}),
                 trips: %{b_branch_trip.id => b_branch_trip, c_branch_trip.id => c_branch_trip}
               })
    end

    test "summary with branching GL on branch", %{now: now} do
      kenmore = build(:stop, name: "Kenmore", child_stop_ids: ["70150"])
      blandford = build(:stop, name: "Blandford Street", child_stop_ids: ["70148"])
      saint_marys = build(:stop, name: "Saint Mary's Street", child_stop_ids: ["70212"])
      c_branch_terminal = build(:stop, name: "Cleveland Circle", child_stop_ids: ["70237"])

      child_stops = [
        build(:stop, id: "70150", parent_station_id: kenmore.id),
        build(:stop, id: "70148", parent_station_id: blandford.id),
        build(:stop, id: "70212", parent_station_id: saint_marys.id),
        build(:stop, id: "70237", parent_station_id: c_branch_terminal.id)
      ]

      route =
        build(:route,
          id: "Green-C",
          type: :light_rail,
          line_id: "line-Green",
          direction_names: ["Westbound", "Eastbound"],
          direction_destinations: ["", "Park St & North"]
        )

      c_branch_trip = build(:trip, stop_ids: ["70237", "70212", "70150"])

      c_branch =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 1,
          representative_trip_id: c_branch_trip.id
        )

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity:
            Enum.map(
              ["70150", "70148", "70212"],
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                stop: &1
              }
            )
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.SuccessiveStops{
                 start_stop_name: "Saint Mary's Street",
                 end_stop_name: "Kenmore"
               }
             } =
               AlertSummary.summarizing(alert, saint_marys.id, 1, [c_branch], now, nil, %{
                 routes: %{route.id => route},
                 stops:
                   Map.new(
                     [kenmore, blandford, saint_marys, c_branch_terminal | child_stops],
                     &{&1.id, &1}
                   ),
                 trips: %{c_branch_trip.id => c_branch_trip}
               })
    end

    test "summary with branching GL on opposite and disconnected branch", %{now: now} do
      medford_tufts = build(:stop, id: "M", name: "Medford/Tufts", child_stop_ids: ["70511"])
      heath_street = build(:stop, id: "H", name: "Heath Street", child_stop_ids: ["70260"])
      kenmore = build(:stop, id: "K", name: "Kenmore", child_stop_ids: ["70151", "71151"])
      blandford = build(:stop, id: "B", name: "Blandford Street", child_stop_ids: ["70149"])
      saint_marys = build(:stop, id: "S", name: "Saint Mary's Street", child_stop_ids: ["70211"])
      parent_stations = [medford_tufts, heath_street, kenmore, blandford, saint_marys]

      child_stops =
        parent_stations
        |> Enum.flat_map(fn %{id: parent_station_id, child_stop_ids: child_stop_ids} ->
          Enum.map(child_stop_ids, &build(:stop, id: &1, parent_station_id: parent_station_id))
        end)

      route =
        build(:route,
          type: :light_rail,
          line_id: "line-Green",
          direction_names: ["Westbound", "Eastbound"],
          direction_destinations: ["Copley & West", "Medford/Tufts"]
        )

      e_branch_trip = build(:trip, stop_ids: ["70511", "70260"])

      e_branch =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          representative_trip_id: e_branch_trip.id
        )

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          informed_entity:
            [kenmore, blandford, saint_marys]
            |> Enum.flat_map(&[&1.id | &1.child_stop_ids])
            |> Enum.map(
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                stop: &1
              }
            )
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.StopToDirection{
                 start_stop_name: "Kenmore",
                 direction: %Direction{name: "Westbound", destination: "Copley & West", id: 0}
               }
             } =
               AlertSummary.summarizing(alert, medford_tufts.id, 0, [e_branch], now, nil, %{
                 routes: %{route.id => route},
                 stops: Map.new(parent_stations ++ child_stops, &{&1.id, &1}),
                 trips: %{e_branch_trip.id => e_branch_trip}
               })
    end

    test "summary with daily recurrence ending on a later date", %{now: now} do
      today = DateTime.to_date(now)
      time_start = DateTime.to_time(now)
      time_end = Time.add(time_start, 1, :second)

      alert =
        build(:alert,
          effect: :suspension,
          duration_certainty: :known,
          active_period:
            Enum.map(0..30, fn days_forward ->
              this_day = Date.add(today, days_forward)

              %Alert.ActivePeriod{
                start: DateTime.new!(this_day, time_start, "America/New_York"),
                end: DateTime.new!(this_day, time_end, "America/New_York")
              }
            end)
        )

      now_plus_one_second = DateTime.add(now, 1, :second)
      end_time = DateTime.new!(Date.add(today, 30), time_end, "America/New_York")

      assert %AlertSummary.Standard{
               timeframe: %AlertSummary.Timeframe.TimeRange{
                 start_time: %AlertSummary.Timeframe.TimeRange.Time{time: ^now},
                 end_time: %AlertSummary.Timeframe.TimeRange.Time{time: ^now_plus_one_second}
               },
               recurrence: %AlertSummary.Recurrence.Daily{
                 ending: %AlertSummary.Timeframe.LaterDate{time: ^end_time}
               }
             } = AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with daily recurrence until further notice", %{now: now} do
      today = DateTime.to_date(now)
      time_start = DateTime.to_time(now)
      time_end = Time.add(time_start, 1, :second)

      alert =
        build(:alert,
          effect: :suspension,
          duration_certainty: :unknown,
          active_period:
            Enum.map(0..30, fn days_forward ->
              this_day = Date.add(today, days_forward)

              %Alert.ActivePeriod{
                start: DateTime.new!(this_day, time_start, "America/New_York"),
                end: DateTime.new!(this_day, time_end, "America/New_York")
              }
            end)
        )

      now_plus_one_second = DateTime.add(now, 1, :second)

      assert %AlertSummary.Standard{
               timeframe: %AlertSummary.Timeframe.TimeRange{
                 start_time: %AlertSummary.Timeframe.TimeRange.Time{time: ^now},
                 end_time: %AlertSummary.Timeframe.TimeRange.Time{time: ^now_plus_one_second}
               },
               recurrence: %AlertSummary.Recurrence.Daily{
                 ending: %AlertSummary.Timeframe.UntilFurtherNotice{}
               }
             } = AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with MWF recurrence ending later this week" do
      monday = ~D[2026-01-12]
      tuesday = ~D[2026-01-13]
      wednesday = ~D[2026-01-14]
      thursday = ~D[2026-01-15]
      friday = ~D[2026-01-16]
      saturday = ~D[2026-01-17]
      service_boundary = ~T[03:00:00]
      noon = ~T[12:00:00]

      alert =
        build(:alert,
          effect: :suspension,
          duration_certainty: :known,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.new!(monday, service_boundary, "America/New_York"),
              end: DateTime.new!(tuesday, service_boundary, "America/New_York")
            },
            %Alert.ActivePeriod{
              start: DateTime.new!(wednesday, service_boundary, "America/New_York"),
              end: DateTime.new!(thursday, service_boundary, "America/New_York")
            },
            %Alert.ActivePeriod{
              start: DateTime.new!(friday, service_boundary, "America/New_York"),
              end: DateTime.new!(saturday, service_boundary, "America/New_York")
            }
          ]
        )

      expected_recurrence = %AlertSummary.Recurrence.SomeDays{
        ending: %AlertSummary.Timeframe.ThisWeek{
          time: DateTime.new!(saturday, service_boundary, "America/New_York")
        }
      }

      assert %AlertSummary.Standard{
               timeframe: %AlertSummary.Timeframe.TimeRange{
                 start_time: %AlertSummary.Timeframe.TimeRange.StartOfService{},
                 end_time: %AlertSummary.Timeframe.TimeRange.EndOfService{}
               },
               recurrence: ^expected_recurrence
             } =
               AlertSummary.summarizing(
                 alert,
                 "",
                 0,
                 [],
                 DateTime.new!(monday, noon, "America/New_York"),
                 nil,
                 %{}
               )

      assert %AlertSummary.Standard{
               timeframe: %AlertSummary.Timeframe.StartingTomorrow{},
               recurrence: ^expected_recurrence
             } =
               AlertSummary.summarizing(
                 alert,
                 "",
                 0,
                 [],
                 DateTime.new!(tuesday, noon, "America/New_York"),
                 nil,
                 %{}
               )
    end

    test "summary with active update", %{now: now} do
      end_time = DateTime.add(now, 1, :hour)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}],
          updated_at: DateTime.add(now, -4, :minute)
        )

      assert %AlertSummary.Standard{
               timeframe: %AlertSummary.Timeframe.Time{time: ^end_time},
               is_update: true
             } = AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with all_clear update", %{now: now} do
      start_time = DateTime.add(now, -1, :hour)
      end_time = DateTime.add(now, -30, :minute)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: start_time, end: end_time}],
          closed_timestamp: end_time
        )

      assert %AlertSummary.AllClear{location: nil} =
               AlertSummary.summarizing(alert, "", 0, [], now, nil, %{})
    end

    test "summary with whole route entity", %{now: now} do
      route = build(:route, short_name: "Route Label", type: :bus)
      pattern = build(:route_pattern, route_id: route.id, direction_id: 0)

      alert =
        build(:alert,
          effect: :suspension,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: nil}],
          informed_entity: [
            %Alert.InformedEntity{
              activities: ~w(board exit ride)a,
              route: route.id,
              route_type: route.type
            }
          ]
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.WholeRoute{
                 route_label: "Route Label",
                 route_type: :bus
               },
               timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
             } =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, nil, %{
                 routes: %{route.id => route}
               })
    end

    test "summary with stop entities for every stop on a route", %{now: now} do
      route = build(:route, long_name: "Route Label", type: :heavy_rail)
      stop_ids = ["1", "2", "3", "4"]
      stops = Map.new(stop_ids, &{&1, build(:stop, id: &1)})
      trip = build(:trip, stop_ids: stop_ids)

      pattern =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          typicality: :typical,
          representative_trip_id: trip.id
        )

      alert =
        build(:alert,
          effect: :suspension,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: nil}],
          informed_entity:
            Enum.map(
              stop_ids,
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: route.id,
                route_type: route.type,
                stop: &1
              }
            )
        )

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.WholeRoute{
                 route_label: "Route Label",
                 route_type: :heavy_rail
               },
               timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
             } =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, nil, %{
                 routes: %{route.id => route},
                 stops: stops,
                 trips: %{trip.id => trip}
               })
    end

    test "summary with whole green line alert", %{now: now} do
      green_route_ids = ~w(Green-B Green-C Green-D Green-E)

      routes =
        Map.new(green_route_ids, fn id ->
          route = build(:route, id: id, type: :light_rail, line_id: "line-Green")
          {id, route}
        end)

      patterns =
        Enum.map(green_route_ids, fn id ->
          build(:route_pattern,
            route_id: id,
            direction_id: 0,
            typicality: :typical
          )
        end)

      alert =
        build(:alert,
          effect: :stop_closure,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: nil}],
          informed_entity:
            Enum.map(
              green_route_ids,
              &%Alert.InformedEntity{
                activities: ~w(board exit ride)a,
                route: &1,
                route_type: :light_rail
              }
            )
        )

      e_patterns = Enum.filter(patterns, &(&1.route_id == "Green-E"))

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.WholeRoute{
                 route_label: "Green Line",
                 route_type: :light_rail
               },
               timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
             } =
               AlertSummary.summarizing(alert, "stopId", 0, e_patterns, now, nil, %{
                 routes: routes
               })
    end

    test "summary with stop entities for every stop on the green line", %{now: now} do
      green_route_ids = ~w(Green-B Green-C Green-D Green-E)

      routes =
        Map.new(green_route_ids, fn id ->
          route = build(:route, id: id, type: :light_rail, line_id: "line-Green")
          {id, route}
        end)

      trunk_stop_ids = ["trunk1", "trunk2", "trunk3", "trunk4"]
      trunk_stops = Map.new(trunk_stop_ids, &{&1, build(:stop, id: &1)})

      {branch_stops, trips, patterns} =
        Enum.reduce(green_route_ids, {%{}, %{}, []}, fn route_id,
                                                        {stops_acc, trips_acc, pats_acc} ->
          branch_ids = Enum.map(1..4, &"#{route_id}-stop-#{&1}")
          branch_stop_map = Map.new(branch_ids, &{&1, build(:stop, id: &1)})
          trip = build(:trip, stop_ids: branch_ids ++ trunk_stop_ids)

          pattern =
            build(:route_pattern,
              route_id: route_id,
              direction_id: 0,
              typicality: :typical,
              representative_trip_id: trip.id
            )

          {Map.merge(stops_acc, branch_stop_map), Map.put(trips_acc, trip.id, trip),
           pats_acc ++ [pattern]}
        end)

      all_stops = Map.merge(branch_stops, trunk_stops)

      branch_entities =
        Enum.flat_map(green_route_ids, fn route_id ->
          branch_ids = Enum.map(1..4, &"#{route_id}-stop-#{&1}")

          Enum.map(
            branch_ids,
            &%Alert.InformedEntity{activities: ~w(board exit ride)a, route: route_id, stop: &1}
          )
        end)

      trunk_entities =
        Enum.flat_map(trunk_stop_ids, fn stop_id ->
          Enum.map(green_route_ids, fn route_id ->
            %Alert.InformedEntity{
              activities: ~w(board exit ride)a,
              route: route_id,
              stop: stop_id
            }
          end)
        end)

      alert =
        build(:alert,
          effect: :stop_closure,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: nil}],
          informed_entity: branch_entities ++ trunk_entities
        )

      e_patterns = Enum.filter(patterns, &(&1.route_id == "Green-E"))

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.WholeRoute{
                 route_label: "Green Line",
                 route_type: :light_rail
               },
               timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
             } =
               AlertSummary.summarizing(alert, "stopId", 0, e_patterns, now, nil, %{
                 routes: routes,
                 stops: all_stops,
                 trips: trips,
                 route_patterns: Map.new(patterns, &{&1.id, &1})
               })
    end

    test "summary for whole other green line branch", %{now: now} do
      green_route_ids = ~w(Green-B Green-C Green-D Green-E)

      routes =
        Map.new(green_route_ids, fn id ->
          route = build(:route, id: id, long_name: id, type: :light_rail, line_id: "line-Green")
          {id, route}
        end)

      stops =
        Map.new(
          Enum.flat_map(green_route_ids, fn id ->
            ["#{id}-stop-1", "#{id}-stop-2"]
            |> Enum.map(&{&1, build(:stop, id: &1)})
          end)
        )

      trips =
        Map.new(green_route_ids, fn id ->
          trip = build(:trip, id: id, stop_ids: ["#{id}-stop-1", "#{id}-stop-2"])
          {id, trip}
        end)

      patterns =
        Enum.map(green_route_ids, fn id ->
          build(:route_pattern,
            route_id: id,
            direction_id: 0,
            typicality: :typical,
            representative_trip_id: id
          )
        end)

      alert =
        build(:alert,
          effect: :stop_closure,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: nil}],
          informed_entity: [
            %Alert.InformedEntity{
              activities: ~w(board exit ride)a,
              route: "Green-C",
              route_type: :light_rail
            }
          ]
        )

      e_pattern = Enum.filter(patterns, &(&1.route_id == "Green-E"))

      assert %AlertSummary.Standard{
               location: %AlertSummary.Location.WholeRoute{
                 route_label: "Green-C",
                 route_type: :light_rail
               },
               timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
             } =
               AlertSummary.summarizing(alert, "stopId", 0, e_pattern, now, nil, %{
                 routes: routes,
                 route_patterns: Map.new(patterns, &{&1.id, &1}),
                 trips: trips,
                 stops: stops
               })
    end

    test "trip specific suspension" do
      now = ~B[2026-03-12 12:00:00]
      stop = build(:stop, name: "Ruggles")
      route = build(:route)
      pattern = build(:route_pattern, route_id: route.id)
      trip = build(:trip, route_pattern_id: pattern.id)

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(now, -2, :hour),
              end: DateTime.add(now, 2, :hour)
            }
          ],
          cause: :weather,
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{trip: trip.id}]
        )

      schedule =
        build(:schedule,
          trip_id: trip.id,
          departure_time: ~B[2026-03-12 12:13:00]
        )

      trip_time = schedule.departure_time

      assert %AlertSummary.TripSpecific{
               trip_identity: %AlertSummary.TripSpecific.TripFrom{
                 trip_time: ^trip_time,
                 stop_name: "Ruggles"
               },
               effect: :suspension,
               effect_stops: nil,
               is_today: true,
               cause: :weather,
               recurrence: nil
             } =
               AlertSummary.summarizing(alert, stop.id, 0, [pattern], now, [schedule], %{
                 stops: %{stop.id => stop}
               })
    end

    test "multiple trip cancellation" do
      now = ~B[2026-03-12 12:00:00]
      stop = build(:stop, name: "Blossom Street Pier")
      route = build(:route)
      pattern = build(:route_pattern, route_id: route.id)
      [trip1, trip2] = build_pair(:trip, route_pattern_id: pattern.id)

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(now, -2, :hour),
              end: DateTime.add(now, 2, :hour)
            }
          ],
          cause: :ice_in_harbor,
          effect: :cancellation,
          informed_entity: [
            %Alert.InformedEntity{trip: trip1.id},
            %Alert.InformedEntity{trip: trip2.id}
          ]
        )

      schedule1 =
        build(:schedule,
          trip_id: trip1.id,
          departure_time: ~B[2026-03-12 18:00:00]
        )

      schedule2 =
        build(:schedule,
          trip_id: trip1.id,
          departure_time: ~B[2026-03-12 18:30:00]
        )

      assert %AlertSummary.TripSpecific{
               trip_identity: %AlertSummary.TripSpecific.MultipleTrips{},
               effect: :cancellation,
               effect_stops: nil,
               is_today: true,
               cause: :ice_in_harbor,
               recurrence: nil
             } =
               AlertSummary.summarizing(
                 alert,
                 stop.id,
                 0,
                 [pattern],
                 now,
                 [schedule1, schedule2],
                 %{}
               )
    end

    test "trip specific shuttle" do
      now = ~B[2026-03-12 12:00:00]
      stop1 = build(:stop, name: "Ruggles")
      stop2 = build(:stop, name: "Forest Hills")
      route = build(:route, type: :commuter_rail)
      representative_trip = build(:trip, stop_ids: [build(:stop).id, stop1.id, stop2.id])

      pattern =
        build(:route_pattern, representative_trip_id: representative_trip.id, route_id: route.id)

      trip = build(:trip, route_pattern_id: pattern.id)

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(now, -2, :hour),
              end: DateTime.add(now, 2, :hour)
            }
          ],
          effect: :shuttle,
          informed_entity: [
            %Alert.InformedEntity{stop: stop1.id, trip: trip.id},
            %Alert.InformedEntity{stop: stop2.id, trip: trip.id}
          ]
        )

      schedule =
        build(:schedule,
          trip_id: trip.id,
          departure_time: ~B[2026-03-12 12:13:00]
        )

      trip_time = schedule.departure_time

      assert %AlertSummary.TripShuttle{
               trip_identity: %AlertSummary.TripShuttle.SingleTrip{
                 trip_time: ^trip_time,
                 route_type: :commuter_rail
               },
               is_today: true,
               current_stop_name: "Ruggles",
               end_stop_name: "Forest Hills",
               recurrence: nil
             } =
               AlertSummary.summarizing(alert, stop1.id, 0, [pattern], now, [schedule], %{
                 routes: %{route.id => route},
                 stops: %{stop1.id => stop1, stop2.id => stop2},
                 trips: %{representative_trip.id => representative_trip}
               })
    end

    test "trip specific station bypass" do
      now = ~B[2026-03-12 12:00:00]
      stop1 = build(:stop, name: "Ruggles")
      stop2 = build(:stop, name: "Back Bay")
      route = build(:route, type: :commuter_rail)
      pattern = build(:route_pattern, route_id: route.id)
      trip = build(:trip, headsign: "Stoughton", route_pattern_id: pattern.id)
      trip_id = trip.id

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(now, -2, :hour),
              end: DateTime.add(now, 2, :hour)
            }
          ],
          effect: :station_closure,
          informed_entity: [
            %Alert.InformedEntity{stop: stop2.id, trip: trip.id},
            %Alert.InformedEntity{stop: stop1.id, trip: trip.id}
          ]
        )

      schedule =
        build(:schedule,
          trip_id: trip.id,
          departure_time: ~B[2026-03-12 12:13:00]
        )

      trip_time = schedule.departure_time

      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      RepositoryMock
      |> expect(:trips, fn [filter: [id: ^trip_id]], _ ->
        ok_response([trip])
      end)

      assert %AlertSummary.TripSpecific{
               trip_identity: %AlertSummary.TripSpecific.TripTo{
                 trip_time: ^trip_time,
                 headsign: "Stoughton"
               },
               effect: :station_closure,
               effect_stops: ["Back Bay", "Ruggles"]
             } =
               AlertSummary.summarizing(alert, stop1.id, 0, [pattern], now, [schedule], %{
                 stops: %{stop1.id => stop1, stop2.id => stop2}
               })
    end

    test "trip specific reminder" do
      now = ~B[2026-03-12 12:00:00]
      stop = build(:stop, name: "Ruggles")
      route = build(:route)
      pattern = build(:route_pattern, route_id: route.id)
      trip = build(:trip, route_pattern_id: pattern.id)

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: now |> DateTime.add(1, :day) |> DateTime.add(-2, :hour),
              end: now |> DateTime.add(1, :day) |> DateTime.add(2, :hour)
            }
          ],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{trip: trip.id}]
        )

      schedule =
        build(:schedule,
          trip_id: trip.id,
          departure_time: ~B[2026-03-13 12:13:00]
        )

      trip_time = schedule.departure_time

      assert %AlertSummary.TripSpecific{
               trip_identity: %AlertSummary.TripSpecific.TripFrom{
                 trip_time: ^trip_time,
                 stop_name: "Ruggles"
               },
               effect: :suspension,
               is_today: false
             } =
               AlertSummary.summarizing(alert, stop.id, 0, [pattern], now, [schedule], %{
                 stops: %{stop.id => stop}
               })
    end

    test "trip shuttle recurrence" do
      now = ~B[2026-03-09 12:00:00]
      stop1 = build(:stop, name: "Ruggles")
      stop2 = build(:stop, name: "Forest Hills")
      route = build(:route, type: :commuter_rail)
      representative_trip = build(:trip, stop_ids: [build(:stop).id, stop1.id, stop2.id])

      pattern =
        build(:route_pattern, representative_trip_id: representative_trip.id, route_id: route.id)

      trip = build(:trip, route_pattern_id: pattern.id)

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{start: ~B[2026-03-09 12:00:00], end: ~B[2026-03-09 14:00:00]},
            %Alert.ActivePeriod{start: ~B[2026-03-10 12:00:00], end: ~B[2026-03-10 14:00:00]},
            %Alert.ActivePeriod{start: ~B[2026-03-11 12:00:00], end: ~B[2026-03-11 14:00:00]},
            %Alert.ActivePeriod{start: ~B[2026-03-12 12:00:00], end: ~B[2026-03-12 14:00:00]},
            %Alert.ActivePeriod{start: ~B[2026-03-13 12:00:00], end: ~B[2026-03-13 14:00:00]}
          ],
          duration_certainty: :known,
          effect: :shuttle,
          informed_entity: [
            %Alert.InformedEntity{stop: stop1.id, trip: trip.id},
            %Alert.InformedEntity{stop: stop2.id, trip: trip.id}
          ]
        )

      schedule =
        build(:schedule,
          trip_id: trip.id,
          departure_time: ~B[2026-03-09 13:00:00]
        )

      trip_time = schedule.departure_time
      end_time = ~B[2026-03-13 14:00:00]

      assert %AlertSummary.TripShuttle{
               trip_identity: %AlertSummary.TripShuttle.SingleTrip{
                 trip_time: ^trip_time,
                 route_type: :commuter_rail
               },
               is_today: true,
               current_stop_name: "Ruggles",
               end_stop_name: "Forest Hills",
               recurrence: %AlertSummary.Recurrence.Daily{
                 ending: %AlertSummary.Timeframe.ThisWeek{time: ^end_time}
               }
             } =
               AlertSummary.summarizing(alert, stop1.id, 0, [pattern], now, [schedule], %{
                 routes: %{route.id => route},
                 stops: %{stop1.id => stop1, stop2.id => stop2},
                 trips: %{representative_trip.id => representative_trip}
               })
    end
  end

  describe "combine_summaries/2" do
    test "keeps identical summary from multiple routes" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, 1), end: nil}],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], stop: "place-sstat"}]
        )

      summary1 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      summary2 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert summary1 ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "keeps successive stops if subscribed in both directions" do
      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], stop: "place-boyls", route: "Green-D"},
            %Alert.InformedEntity{activities: [:board], stop: "place-river", route: "Green-D"}
          ]
        )

      summary1 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SuccessiveStops{
          start_stop_name: "Boylston",
          end_stop_name: "Riverside"
        },
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      summary2 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SuccessiveStops{
          start_stop_name: "Riverside",
          end_stop_name: "Boylston"
        },
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert summary1 ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "keeps stop to direction if given both directions" do
      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], stop: "place-boyls", route: "Green-D"},
            %Alert.InformedEntity{activities: [:board], stop: "place-river", route: "Green-D"}
          ]
        )

      summary1 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.StopToDirection{
          start_stop_name: "North Station",
          direction: %Direction{name: "Southbound", destination: "Forest Hills", id: 1}
        },
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      summary2 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.DirectionToStop{
          end_stop_name: "North Station",
          direction: %Direction{name: "Northbound", destination: "Oak Grove", id: 0}
        },
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert summary1 ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "discards location if disagreements" do
      now = DateTime.now!("America/New_York")
      upstream_timestamp = DateTime.add(now, -2)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, 1), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat"},
            %Alert.InformedEntity{activities: [:board], stop: "place-brdwy"}
          ],
          last_push_notification_timestamp: upstream_timestamp
        )

      summary1 = %AlertSummary.Standard{
        effect: :suspension,
        location: %Location.SuccessiveStops{start_stop_name: "A", end_stop_name: "B"}
      }

      summary2 = %AlertSummary.Standard{
        effect: :suspension,
        location: %Location.SuccessiveStops{start_stop_name: "A", end_stop_name: "C"}
      }

      assert %AlertSummary.Standard{
               effect: :suspension,
               location: nil,
               timeframe: nil
             } =
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "keeps timeframe if same" do
      now = DateTime.now!("America/New_York")
      upstream_timestamp = DateTime.add(now, -2)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, 1), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat"},
            %Alert.InformedEntity{activities: [:board], stop: "place-brdwy"}
          ],
          last_push_notification_timestamp: upstream_timestamp
        )

      summary1 = %AlertSummary.Standard{
        effect: :suspension,
        location: %Location.SuccessiveStops{
          start_stop_name: "A",
          end_stop_name: "B"
        },
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      summary2 = %AlertSummary.Standard{
        effect: :suspension,
        location: %Location.SuccessiveStops{start_stop_name: "A", end_stop_name: "C"},
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert %AlertSummary.Standard{
               effect: :suspension,
               location: nil,
               timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
             } =
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "returns a single all clear when multiple subscriptions match" do
      now = DateTime.now!("America/New_York")
      upstream_timestamp = DateTime.add(now, -2)

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{start: DateTime.add(now, -10), end: DateTime.add(now, -5)}
          ],
          closed_timestamp: upstream_timestamp,
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat"},
            %Alert.InformedEntity{activities: [:board], stop: "place-brdwy"}
          ],
          last_push_notification_timestamp: upstream_timestamp
        )

      summary1 = %AlertSummary.AllClear{
        location: %Location.SuccessiveStops{start_stop_name: "A", end_stop_name: "B"}
      }

      summary2 = %AlertSummary.AllClear{
        location: %Location.SuccessiveStops{start_stop_name: "C", end_stop_name: "D"}
      }

      assert %AlertSummary.AllClear{
               location: nil
             } =
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "trip specific - same trip and stops" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              stop: "place-sstat",
              route: "CR-Franklin"
            },
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Franklin"},
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat", route: "CR-Needham"},
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Needham"}
          ]
        )

      summary1 = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{trip_time: now, stop_name: "South Station"},
        effect: :suspension,
        effect_stops: ["place-sstat", "place-rugg"],
        is_today: true,
        cause: nil,
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      summary2 = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{trip_time: now, stop_name: "South Station"},
        effect: :suspension,
        effect_stops: ["place-sstat", "place-rugg"],
        is_today: true,
        cause: nil,
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      assert summary1 ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "trip specific - same stops different trips" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              stop: "place-sstat",
              route: "CR-Franklin"
            },
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Franklin"},
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat", route: "CR-Needham"},
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Needham"}
          ]
        )

      summary1 = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{trip_time: now, stop_name: "South Station"},
        effect: :suspension,
        effect_stops: ["place-sstat", "place-rugg"],
        is_today: true,
        cause: nil,
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      summary2 = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{
          trip_time: DateTime.add(now, 2),
          stop_name: "Needham"
        },
        effect: :suspension,
        effect_stops: ["place-sstat", "place-rugg"],
        is_today: true,
        cause: nil,
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      assert %AlertSummary.TripSpecific{
               trip_identity: %TripSpecific.MultipleTrips{},
               effect: :suspension,
               effect_stops: ["place-sstat", "place-rugg"],
               is_today: true,
               cause: nil,
               recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
             } ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "trip specific - different stops and trips" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              stop: "place-sstat",
              route: "CR-Franklin"
            },
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Franklin"},
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat", route: "CR-Needham"},
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Needham"}
          ]
        )

      summary1 = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{trip_time: now, stop_name: "South Station"},
        effect: :suspension,
        effect_stops: ["place-sstat"],
        is_today: true,
        cause: nil,
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      summary2 = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{
          trip_time: DateTime.add(now, 2),
          stop_name: "Needham"
        },
        effect: :suspension,
        effect_stops: nil,
        is_today: true,
        cause: nil,
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      assert %AlertSummary.Standard{
               effect: :suspension,
               recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
             } ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "trip shuttle - same trip and stops" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              stop: "place-sstat",
              route: "CR-Franklin"
            },
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Franklin"},
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat", route: "CR-Needham"},
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Needham"}
          ]
        )

      summary1 = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{trip_time: now, route_type: :commuter_Rail},
        is_today: true,
        current_stop_name: "South Station",
        end_stop_name: "Ruggles",
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      summary2 = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{trip_time: now, route_type: :commuter_Rail},
        is_today: true,
        current_stop_name: "South Station",
        end_stop_name: "Ruggles",
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      assert summary1 ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "trip shuttle - same stops different trips" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              stop: "place-sstat",
              route: "CR-Franklin"
            },
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Franklin"},
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat", route: "CR-Needham"},
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Needham"}
          ]
        )

      summary1 = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{trip_time: now, route_type: :commuter_Rail},
        is_today: true,
        current_stop_name: "South Station",
        end_stop_name: "Ruggles",
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      summary2 = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{
          trip_time: DateTime.add(now, 2),
          route_type: :commuter_Rail
        },
        is_today: true,
        current_stop_name: "South Station",
        end_stop_name: "Ruggles",
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      assert %AlertSummary.TripShuttle{
               trip_identity: %TripShuttle.MultipleTrips{},
               is_today: true,
               current_stop_name: "South Station",
               end_stop_name: "Ruggles",
               recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
             } ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "trip shuttle - different stops and trips" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              stop: "place-sstat",
              route: "CR-Franklin"
            },
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Franklin"},
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat", route: "CR-Needham"},
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Needham"}
          ]
        )

      summary1 = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{trip_time: now, route_type: :commuter_Rail},
        is_today: true,
        current_stop_name: "South Station",
        end_stop_name: "Ruggles",
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      summary2 = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{
          trip_time: DateTime.add(now, 2),
          route_type: :commuter_Rail
        },
        is_today: true,
        current_stop_name: "Needham",
        end_stop_name: "Ruggles",
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      assert %AlertSummary.Standard{
               effect: :suspension,
               recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
             } ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end

    test "unresolvably different summaries result in standard summary" do
      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              stop: "place-sstat",
              route: "CR-Franklin"
            },
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Franklin"},
            %Alert.InformedEntity{activities: [:board], stop: "place-sstat", route: "CR-Needham"},
            %Alert.InformedEntity{activities: [:board], stop: "place-rugg", route: "CR-Needham"}
          ]
        )

      summary1 = %AlertSummary.Standard{
        effect: :suspension,
        recurrence: %Recurrence.Daily{ending: %Timeframe.Tomorrow{}}
      }

      summary2 = %AlertSummary.TripSpecific{
        trip_identity: %TripShuttle.MultipleTrips{},
        effect: :suspension,
        effect_stops: ["place-sstat", "place-rugg"],
        is_today: true,
        recurrence: %Recurrence.Daily{ending: %Timeframe.EndOfService{}}
      }

      assert %AlertSummary.Standard{
               effect: :suspension,
               recurrence: nil
             } ==
               AlertSummary.combine_summaries(alert, [summary1, summary2])
    end
  end
end

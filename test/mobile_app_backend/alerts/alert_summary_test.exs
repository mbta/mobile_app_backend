defmodule MobileAppBackend.Alerts.AlertSummaryTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory
  import Test.Support.Sigils
  require Jason.Sigil
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.Direction
  alias MobileAppBackend.GlobalDataCache

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

    test "can serialize full summary" do
      assert json_round_trip(%AlertSummary{
               effect: :station_closure,
               location: %AlertSummary.Location.SingleStop{stop_name: "Lechmere"},
               timeframe: %AlertSummary.Timeframe.Tomorrow{}
             }) ==
               %{
                 effect: "station_closure",
                 location: %{
                   type: "single_stop",
                   stop_name: "Lechmere"
                 },
                 timeframe: %{type: "tomorrow"}
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
    end
  end

  describe "summarizing/6" do
    test "summary with later today timeframe", %{now: now} do
      end_time = DateTime.add(now, 1, :hour)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary{timeframe: %AlertSummary.Timeframe.Time{time: ^end_time}} =
               AlertSummary.summarizing(alert, "", 0, [], now, %{})
    end

    test "summary with end of service timeframe", %{now: now} do
      tomorrow = Util.datetime_to_gtfs(now) |> Date.add(1)
      end_time = DateTime.new!(tomorrow, ~T[02:59:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary{timeframe: %AlertSummary.Timeframe.EndOfService{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, %{})
    end

    test "summary with alt end of service timeframe", %{now: now} do
      tomorrow = Util.datetime_to_gtfs(now) |> Date.add(1)
      end_time = DateTime.new!(tomorrow, ~T[03:00:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary{timeframe: %AlertSummary.Timeframe.EndOfService{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, %{})
    end

    test "summary with tomorrow timeframe", %{now: now} do
      # Set to tomorrow's end of service, with a date of 2 days from now
      tomorrow = Util.datetime_to_gtfs(now) |> Date.add(2)
      end_time = DateTime.new!(tomorrow, ~T[03:00:00], "America/New_York")

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1, :hour), end: end_time}]
        )

      assert %AlertSummary{timeframe: %AlertSummary.Timeframe.Tomorrow{}} =
               AlertSummary.summarizing(alert, "", 0, [], now, %{})
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

      assert %AlertSummary{timeframe: %AlertSummary.Timeframe.ThisWeek{time: ^end_time}} =
               AlertSummary.summarizing(alert, "", 0, [], now, %{})
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

      assert %AlertSummary{timeframe: %AlertSummary.Timeframe.LaterDate{time: ^end_time}} =
               AlertSummary.summarizing(alert, "", 0, [], now, %{})
    end

    test "summary with single stop", %{now: now} do
      stop = build(:stop, name: "Parent Name")
      child_stop = build(:stop, parent_station_id: stop.id)
      stop = put_in(stop.child_stop_ids, [child_stop.id])

      route = build(:route)
      pattern = build(:route_pattern, route_id: route.id, direction_id: 0)

      alert =
        build(:alert,
          informed_entity: [
            %Alert.InformedEntity{
              activities: ~w(board exit ride)a,
              route: route.id,
              stop: child_stop.id
            }
          ]
        )

      assert %AlertSummary{location: %AlertSummary.Location.SingleStop{stop_name: "Parent Name"}} =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, %{
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

      assert %AlertSummary{
               location: %AlertSummary.Location.SuccessiveStops{
                 start_stop_name: "First Stop",
                 end_stop_name: "Last Stop"
               }
             } =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, %{
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

      assert %AlertSummary{location: nil} =
               AlertSummary.summarizing(alert, "", 0, [pattern], now, %{
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

      assert %AlertSummary{
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

      assert %AlertSummary{
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

      assert %AlertSummary{
               location: %AlertSummary.Location.StopToDirection{
                 start_stop_name: "Kenmore",
                 direction: %Direction{name: "Westbound", destination: "", id: 0}
               }
             } =
               AlertSummary.summarizing(alert, kenmore.id, 0, [b_branch, c_branch], now, %{
                 routes: %{route.id => route},
                 stops: Map.new([kenmore, blandford, saint_marys | child_stops], &{&1.id, &1}),
                 trips: %{b_branch_trip.id => b_branch_trip, c_branch_trip.id => c_branch_trip}
               })
    end

    test "summary with branching GL on branch", %{now: now} do
      kenmore = build(:stop, name: "Kenmore", child_stop_ids: ["70150"])
      blandford = build(:stop, name: "Blandford Street", child_stop_ids: ["70148"])
      saint_marys = build(:stop, name: "Saint Mary's Street", child_stop_ids: ["70212"])

      child_stops = [
        build(:stop, id: "70150", parent_station_id: kenmore.id),
        build(:stop, id: "70148", parent_station_id: blandford.id),
        build(:stop, id: "70212", parent_station_id: saint_marys.id)
      ]

      route =
        build(:route,
          type: :light_rail,
          line_id: "line-Green",
          direction_names: ["Westbound", "Eastbound"],
          direction_destinations: ["", "Park St & North"]
        )

      c_branch_trip = build(:trip, stop_ids: ["70212", "70150"])

      c_branch =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 1,
          representative_trip_id: c_branch_trip.id
        )

      alert =
        build(:alert,
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

      assert %AlertSummary{
               location: %AlertSummary.Location.SuccessiveStops{
                 start_stop_name: "Saint Mary's Street",
                 end_stop_name: "Kenmore"
               }
             } =
               AlertSummary.summarizing(alert, saint_marys.id, 1, [c_branch], now, %{
                 routes: %{route.id => route},
                 stops: Map.new([kenmore, blandford, saint_marys | child_stops], &{&1.id, &1}),
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

      assert %AlertSummary{
               location: %AlertSummary.Location.StopToDirection{
                 start_stop_name: "Kenmore",
                 direction: %Direction{name: "Westbound", destination: "Copley & West", id: 0}
               }
             } =
               AlertSummary.summarizing(alert, medford_tufts.id, 0, [e_branch], now, %{
                 routes: %{route.id => route},
                 stops: Map.new(parent_stations ++ child_stops, &{&1.id, &1}),
                 trips: %{e_branch_trip.id => e_branch_trip}
               })
    end
  end
end

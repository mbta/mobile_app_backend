defmodule MobileAppBackend.RouteSegmentTest do
  use ExUnit.Case, async: true
  alias MobileAppBackend.RouteSegment

  import MobileAppBackend.Factory

  describe "non_overlapping_segments/3" do
    test "splits branching route patterns into non-overlapping segments" do
      andrew = build(:stop, id: "andrew", location_type: :station)
      jfk = build(:stop, id: "jfk/umass", location_type: :station)

      jfk_child_1 =
        build(:stop, id: "jfk/umass-1", location_type: :stop, parent_station_id: jfk.id)

      jfk_child_2 =
        build(:stop, id: "jfk/umass-2", location_type: :stop, parent_station_id: jfk.id)

      savin = build(:stop, id: "savin_hill", location_type: :station)
      fields_corner = build(:stop, id: "fields_corner", location_type: :station)
      north_quincy = build(:stop, id: "north_quincy", location_type: :station)
      wollaston = build(:stop, id: "wollaston", location_type: :station)

      stop_map =
        Map.new(
          [andrew, jfk, jfk_child_1, jfk_child_2, savin, fields_corner, north_quincy, wollaston],
          &{&1.id, &1}
        )

      ashmont_trip =
        build(:trip, stop_ids: [andrew.id, jfk_child_1.id, savin.id, fields_corner.id])

      braintree_trip =
        build(:trip, stop_ids: [andrew.id, jfk_child_2.id, north_quincy.id, wollaston.id])

      trip_map = %{ashmont_trip.id => ashmont_trip, braintree_trip.id => braintree_trip}

      ashmont_rp =
        build(:route_pattern,
          id: "red-ashmont",
          representative_trip_id: ashmont_trip.id,
          route_id: "Red"
        )

      braintree_rp =
        build(:route_pattern,
          id: "red-braintree",
          representative_trip_id: braintree_trip.id,
          route_id: "Red"
        )

      route_segments =
        RouteSegment.non_overlapping_segments([ashmont_rp, braintree_rp], stop_map, trip_map)

      assert [
               %RouteSegment{
                 id: "red-ashmont-andrew-fields_corner",
                 source_route_pattern_id: "red-ashmont",
                 route_id: "Red",
                 stop_ids: [andrew.id, jfk.id, savin.id, fields_corner.id]
               },
               %RouteSegment{
                 id: "red-braintree-jfk/umass-wollaston",
                 source_route_pattern_id: "red-braintree",
                 route_id: "Red",
                 stop_ids: [jfk.id, north_quincy.id, wollaston.id]
               }
             ] == route_segments
    end

    test "when overlapping segments are on different routes, both route patterns contain full segments" do
      oak_grove = build(:stop, id: "oak_grove", location_type: :station)
      malden_center = build(:stop, id: "malden", location_type: :station)
      wellington = build(:stop, id: "wellington", location_type: :station)
      north_station = build(:stop, id: "north_station", location_type: :station)

      stop_map =
        Map.new(
          [oak_grove, malden_center, wellington, north_station],
          &{&1.id, &1}
        )

      ol_trip =
        build(:trip, stop_ids: [oak_grove.id, malden_center.id, wellington.id])

      haverhill_trip =
        build(:trip, stop_ids: [oak_grove.id, malden_center.id, north_station.id])

      trip_map = %{ol_trip.id => ol_trip, haverhill_trip.id => haverhill_trip}

      ol_rp =
        build(:route_pattern,
          id: "ol-rp",
          representative_trip_id: ol_trip.id,
          route_id: "Orange"
        )

      harverhill_rp =
        build(:route_pattern,
          id: "haverhill-rp",
          representative_trip_id: haverhill_trip.id,
          route_id: "CR-Haverhill"
        )

      route_segments =
        RouteSegment.non_overlapping_segments([ol_rp, harverhill_rp], stop_map, trip_map)

      assert [
               %RouteSegment{
                 id: "haverhill-rp-oak_grove-north_station",
                 source_route_pattern_id: "haverhill-rp",
                 route_id: "CR-Haverhill",
                 stop_ids: [oak_grove.id, malden_center.id, north_station.id]
               },
               %RouteSegment{
                 id: "ol-rp-oak_grove-wellington",
                 source_route_pattern_id: "ol-rp",
                 route_id: "Orange",
                 stop_ids: [oak_grove.id, malden_center.id, wellington.id]
               }
             ] == route_segments
    end

    test "when overlapping segments are on different routes but should be grouped, breaks into non-overlapping route segments as if they were on the same route" do
      arlington = build(:stop, id: "arlington", location_type: :station)
      copley = build(:stop, id: "copley", location_type: :station)
      prudential = build(:stop, id: "prudential", location_type: :station)
      hynes = build(:stop, id: "hynes", location_type: :station)

      stop_map =
        Map.new(
          [arlington, copley, prudential, hynes],
          &{&1.id, &1}
        )

      green_d_trip =
        build(:trip, stop_ids: [arlington.id, copley.id, hynes.id])

      green_e_trip =
        build(:trip, stop_ids: [arlington.id, copley.id, prudential.id])

      trip_map = %{green_d_trip.id => green_d_trip, green_e_trip.id => green_e_trip}

      green_d_rp =
        build(:route_pattern,
          id: "green_d_rp",
          representative_trip_id: green_d_trip.id,
          route_id: "Green-D"
        )

      green_e_rp =
        build(:route_pattern,
          id: "green_e_rp",
          representative_trip_id: green_e_trip.id,
          route_id: "Green-E"
        )

      route_segments =
        RouteSegment.non_overlapping_segments([green_d_rp, green_e_rp], stop_map, trip_map, %{
          "Green-D" => "Green",
          "Green-E" => "Green"
        })

      assert [
               %RouteSegment{
                 id: "green_d_rp-arlington-hynes",
                 source_route_pattern_id: "green_d_rp",
                 route_id: "Green-D",
                 stop_ids: [arlington.id, copley.id, hynes.id]
               },
               %RouteSegment{
                 id: "green_e_rp-copley-prudential",
                 source_route_pattern_id: "green_e_rp",
                 route_id: "Green-E",
                 stop_ids: [copley.id, prudential.id]
               }
             ] == route_segments
    end
  end

  describe "non_overlapping_segments/1" do
    test "splits branching route patterns into non-overlapping segments" do
      andrew = build(:stop, id: "andrew", location_type: :station)
      jfk = build(:stop, id: "jfk/umass", location_type: :station)
      savin = build(:stop, id: "savin_hill", location_type: :station)
      fields_corner = build(:stop, id: "fields_corner", location_type: :station)
      north_quincy = build(:stop, id: "north_quincy", location_type: :station)
      wollaston = build(:stop, id: "wollaston", location_type: :station)

      rp_ashmont = %{
        id: "red-ashmont",
        route_id: "Red",
        stops: [andrew, jfk, savin, fields_corner]
      }

      rp_braintree = %{
        id: "red-braintree",
        route_id: "Red",
        stops: [andrew, jfk, north_quincy, wollaston]
      }

      route_segments = RouteSegment.non_overlapping_segments([rp_ashmont, rp_braintree])

      assert [
               %RouteSegment{
                 id: "red-ashmont-andrew-fields_corner",
                 source_route_pattern_id: "red-ashmont",
                 route_id: "Red",
                 stop_ids: [andrew.id, jfk.id, savin.id, fields_corner.id]
               },
               %RouteSegment{
                 id: "red-braintree-jfk/umass-wollaston",
                 source_route_pattern_id: "red-braintree",
                 route_id: "Red",
                 stop_ids: [jfk.id, north_quincy.id, wollaston.id]
               }
             ] == route_segments
    end
  end

  describe "segments_with_stops/2" do
    test "when all stops are new, return one segment of all stops" do
      stop1 = build(:stop, id: "stop1", location_type: :stop)
      stop2 = build(:stop, id: "stop2", location_type: :stop)
      stop3 = build(:stop, id: "stop3", location_type: :stop)
      stop4 = build(:stop, id: "stop4", location_type: :stop)
      stop5 = build(:stop, id: "stop5", location_type: :stop)
      stop6 = build(:stop, id: "stop6", location_type: :stop)

      all_stops = [stop1, stop2, stop3, stop4, stop5, stop6]

      segments =
        RouteSegment.unseen_stop_segments(
          %{id: "rp1", route_id: "66", stops: all_stops},
          MapSet.new(Enum.map(all_stops, & &1.id))
        )

      assert [all_stops] == segments
    end

    test "when no stops are new, return empty list" do
      stop1 = build(:stop, id: "stop1", location_type: :stop)
      stop2 = build(:stop, id: "stop2", location_type: :stop)
      stop3 = build(:stop, id: "stop3", location_type: :stop)
      stop4 = build(:stop, id: "stop4", location_type: :stop)
      stop5 = build(:stop, id: "stop5", location_type: :stop)
      stop6 = build(:stop, id: "stop6", location_type: :stop)

      all_stops = [stop1, stop2, stop3, stop4, stop5, stop6]

      assert [] ==
               RouteSegment.unseen_stop_segments(
                 %{id: "rp1", route_id: "66", stops: all_stops},
                 MapSet.new()
               )
    end

    test "when a subset of stops are new, returns segments from those stops & including the boundary stop" do
      stop1 = build(:stop, id: "stop1", location_type: :stop)
      stop2 = build(:stop, id: "stop2", location_type: :stop)
      stop3 = build(:stop, id: "stop3", location_type: :stop)
      stop4 = build(:stop, id: "stop4", location_type: :stop)
      stop5 = build(:stop, id: "stop5", location_type: :stop)
      stop6 = build(:stop, id: "stop6", location_type: :stop)

      all_stops = [stop1, stop2, stop3, stop4, stop5, stop6]
      new_stops = MapSet.new([stop1.id, stop2.id])

      assert [[stop1, stop2, stop3]] ==
               RouteSegment.unseen_stop_segments(
                 %{id: "rp1", route_id: "66", stops: all_stops},
                 new_stops
               )
    end
  end

  describe "split_alerting_segments/2" do
    test "when there is an alert for a stop but on a different route, returns single non-alerting segment" do
      original_segment = %RouteSegment{
        id: "rp1-aa-ff",
        source_route_pattern_id: "rp1",
        route_id: "1",
        stop_ids: ["aa", "bb", "cc", "dd", "ee", "ff"]
      }

      alerts_by_route_and_stop = %{"2" => %{"aa" => build_list(2, :alert)}}

      assert [
               %RouteSegment{
                 id: "rp1-aa-ff",
                 source_route_pattern_id: "rp1",
                 route_id: "1",
                 stop_ids: ["aa", "bb", "cc", "dd", "ee", "ff"],
                 properties: %{has_alert: false}
               }
             ] = RouteSegment.split_alerting_segments(original_segment, alerts_by_route_and_stop)
    end

    test "when alert covers entire segment, returns a single segment" do
      original_segment = %RouteSegment{
        id: "rp1-aa-cc",
        source_route_pattern_id: "rp1",
        route_id: "1",
        stop_ids: ["aa", "bb", "cc"]
      }

      alerts_by_route_and_stop = %{
        "1" => %{"aa" => build(:alert), "bb" => build(:alert), "cc" => build(:alert)}
      }

      assert [
               %RouteSegment{
                 id: "rp1-aa-cc",
                 source_route_pattern_id: "rp1",
                 route_id: "1",
                 stop_ids: ["aa", "bb", "cc"],
                 properties: %{has_alert: true}
               }
             ] = RouteSegment.split_alerting_segments(original_segment, alerts_by_route_and_stop)
    end

    test "when alerts cover subsets of the segment, splits the segment into alerting / non-alerting" do
      original_segment = %RouteSegment{
        id: "rp1-aa-cc",
        source_route_pattern_id: "rp1",
        route_id: "1",
        stop_ids: ["aa", "bb", "cc", "dd", "ee"]
      }

      alerts_by_route_and_stop = %{
        "1" => %{"bb" => build(:alert), "cc" => build(:alert)}
      }

      assert [
               %RouteSegment{
                 id: "rp1-aa-bb",
                 source_route_pattern_id: "rp1",
                 route_id: "1",
                 stop_ids: ["aa", "bb"],
                 properties: %{has_alert: false}
               },
               %RouteSegment{
                 id: "rp1-bb-cc",
                 source_route_pattern_id: "rp1",
                 route_id: "1",
                 stop_ids: ["bb", "cc"],
                 properties: %{has_alert: true}
               },
               %RouteSegment{
                 id: "rp1-cc-ee",
                 source_route_pattern_id: "rp1",
                 route_id: "1",
                 stop_ids: ["cc", "dd", "ee"],
                 properties: %{has_alert: false}
               }
             ] = RouteSegment.split_alerting_segments(original_segment, alerts_by_route_and_stop)
    end
  end

  describe "split_route_segment/2" do
    test "when true for all stops, returns a single segment" do
      original_segment = %RouteSegment{
        id: "rp1-aa-ff",
        source_route_pattern_id: "rp1",
        route_id: "1",
        stop_ids: ["aa", "bb", "cc", "dd", "ee", "ff"]
      }

      assert [
               %RouteSegment{
                 id: "rp1-aa-ff",
                 stop_ids: ["aa", "bb", "cc", "dd", "ee", "ff"],
                 properties: %{len_2: true}
               }
             ] =
               RouteSegment.split_route_segment(original_segment, :len_2, fn stop_id ->
                 String.length(stop_id) == 2
               end)
    end

    test "when false for all stops, returns a single segment" do
      original_segment = %RouteSegment{
        id: "aa-cc",
        source_route_pattern_id: "rp1",
        route_id: "1",
        stop_ids: ["aa", "bb", "cc", "dd", "ee", "ff"]
      }

      assert [
               %RouteSegment{
                 id: "rp1-aa-ff",
                 stop_ids: ["aa", "bb", "cc", "dd", "ee", "ff"],
                 properties: %{len_3: false}
               }
             ] =
               RouteSegment.split_route_segment(original_segment, :len_3, fn stop_id ->
                 String.length(stop_id) == 3
               end)
    end

    test "when true for a segment in the middle, returns split segments" do
      original_segment = %RouteSegment{
        id: "aa-cc",
        source_route_pattern_id: "rp1",
        route_id: "1",
        stop_ids: ["aaa", "bbb", "cc", "dd", "eee", "fff"]
      }

      assert [
               %RouteSegment{
                 id: "rp1-aaa-cc",
                 stop_ids: ["aaa", "bbb", "cc"],
                 properties: %{len_2: false}
               },
               %RouteSegment{
                 id: "rp1-cc-dd",
                 stop_ids: ["cc", "dd"],
                 properties: %{len_2: true}
               },
               %RouteSegment{
                 id: "rp1-dd-fff",
                 stop_ids: ["dd", "eee", "fff"],
                 properties: %{len_2: false}
               }
             ] =
               RouteSegment.split_route_segment(original_segment, :len_2, fn stop_id ->
                 String.length(stop_id) == 2
               end)
    end

    test "when false for a segment in the middle, returns split segments" do
      original_segment = %RouteSegment{
        id: "aa-cc",
        source_route_pattern_id: "rp1",
        route_id: "1",
        stop_ids: ["aaa", "bbb", "cc", "dd", "eee", "fff"]
      }

      assert [
               %RouteSegment{
                 id: "rp1-aaa-bbb",
                 stop_ids: ["aaa", "bbb"],
                 properties: %{len_3: true}
               },
               %RouteSegment{
                 id: "rp1-bbb-eee",
                 stop_ids: ["bbb", "cc", "dd", "eee"],
                 properties: %{len_3: false}
               },
               %RouteSegment{
                 id: "rp1-eee-fff",
                 stop_ids: ["eee", "fff"],
                 properties: %{len_3: true}
               }
             ] =
               RouteSegment.split_route_segment(original_segment, :len_3, fn stop_id ->
                 String.length(stop_id) == 3
               end)
    end
  end

  describe "segment_stops_including_boundary/2" do
    test "when the true segment is in the middle, splits so the true boundaries are in each segment" do
      stop1 = build(:stop, id: "stop1", location_type: :station)
      stop2 = build(:stop, id: "stop2", location_type: :station)
      stop3 = build(:stop, id: "stop3", location_type: :stop)
      stop4 = build(:stop, id: "stop4", location_type: :stop)
      stop5 = build(:stop, id: "stop5", location_type: :stop)
      stop6 = build(:stop, id: "stop6", location_type: :station)

      segments =
        RouteSegment.segment_stops_including_boundary(
          [stop1, stop2, stop3, stop4, stop5, stop6],
          fn stop -> stop.location_type == :stop end
        )

      assert [
               {false, [stop1, stop2, stop3]},
               {true, [stop3, stop4, stop5]},
               {false, [stop5, stop6]}
             ] == segments
    end

    test "when the false segment is in the middle, splits so the true boundaries are in each segment" do
      stop1 = build(:stop, id: "stop1", location_type: :stop)
      stop2 = build(:stop, id: "stop2", location_type: :stop)
      stop3 = build(:stop, id: "stop3", location_type: :station)
      stop4 = build(:stop, id: "stop4", location_type: :station)
      stop5 = build(:stop, id: "stop5", location_type: :station)
      stop6 = build(:stop, id: "stop6", location_type: :stop)

      segments =
        RouteSegment.segment_stops_including_boundary(
          [stop1, stop2, stop3, stop4, stop5, stop6],
          fn stop -> stop.location_type == :stop end
        )

      assert [
               {true, [stop1, stop2]},
               {false, [stop2, stop3, stop4, stop5, stop6]},
               {true, [stop6]}
             ] == segments
    end

    test "when all are true returns a single segment" do
      stop1 = build(:stop, id: "stop1", location_type: :stop)
      stop2 = build(:stop, id: "stop2", location_type: :stop)
      stop3 = build(:stop, id: "stop3", location_type: :stop)
      stop4 = build(:stop, id: "stop4", location_type: :stop)
      stop5 = build(:stop, id: "stop5", location_type: :stop)
      stop6 = build(:stop, id: "stop6", location_type: :stop)

      segments =
        RouteSegment.segment_stops_including_boundary(
          [stop1, stop2, stop3, stop4, stop5, stop6],
          fn stop -> stop.location_type == :stop end
        )

      assert [
               {true, [stop1, stop2, stop3, stop4, stop5, stop6]}
             ] == segments
    end

    test "when all are false returns a single segment" do
      stop1 = build(:stop, id: "stop1", location_type: :stop)
      stop2 = build(:stop, id: "stop2", location_type: :stop)
      stop3 = build(:stop, id: "stop3", location_type: :stop)
      stop4 = build(:stop, id: "stop4", location_type: :stop)
      stop5 = build(:stop, id: "stop5", location_type: :stop)
      stop6 = build(:stop, id: "stop6", location_type: :stop)

      segments =
        RouteSegment.segment_stops_including_boundary(
          [stop1, stop2, stop3, stop4, stop5, stop6],
          fn stop -> stop.location_type == :station end
        )

      assert [
               {false, [stop1, stop2, stop3, stop4, stop5, stop6]}
             ] == segments
    end
  end

  describe "route_pattern_with_stops/3" do
    test "associates a route pattern with its parents stops when available, otherwise uses child stop" do
      parent1 = build(:stop, id: "parent1", location_type: :station)
      parent1child1 = build(:stop, id: "parent1-platform1", parent_station_id: parent1.id)
      parent1child2 = build(:stop, id: "parent1-platform2", parent_station_id: parent1.id)

      parent2 = build(:stop, id: "parent2", location_type: :station)
      parent2child1 = build(:stop, id: "parent2-platform1", parent_station_id: parent2.id)

      stop3 = build(:stop, id: "stop3")
      stop4 = build(:stop, id: "stop4")

      trip1 = build(:trip, %{stop_ids: [parent1child1.id, parent2child1.id, stop3.id]})
      trip2 = build(:trip, %{stop_ids: [parent1child2.id, stop4.id]})

      rp1 = build(:route_pattern, %{representative_trip_id: trip1.id})
      rp2 = build(:route_pattern, %{representative_trip_id: trip2.id})

      assert [
               %{id: rp1.id, route_id: rp1.route_id, stops: [parent1, parent2, stop3]},
               %{id: rp2.id, route_id: rp2.route_id, stops: [parent1, stop4]}
             ] ==
               RouteSegment.route_patterns_with_parent_stops(
                 [rp1, rp2],
                 %{
                   parent1.id => parent1,
                   parent1child1.id => parent1child1,
                   parent1child2.id => parent1child2,
                   parent2.id => parent2,
                   parent2child1.id => parent2child1,
                   stop3.id => stop3,
                   stop4.id => stop4
                 },
                 %{trip1.id => trip1, trip2.id => trip2}
               )
    end
  end
end

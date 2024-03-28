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
               %{
                 id: "andrew-fields_corner",
                 source_route_pattern_id: "red-ashmont",
                 route_id: "Red",
                 stops: [^andrew, ^jfk, ^savin, ^fields_corner]
               },
               %{
                 id: "jfk/umass-wollaston",
                 source_route_pattern_id: "red-braintree",
                 route_id: "Red",
                 stops: [^jfk, ^north_quincy, ^wollaston]
               }
             ] = route_segments
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
               %{
                 id: "andrew-fields_corner",
                 source_route_pattern_id: "red-ashmont",
                 route_id: "Red",
                 stops: [^andrew, ^jfk, ^savin, ^fields_corner]
               },
               %{
                 id: "jfk/umass-wollaston",
                 source_route_pattern_id: "red-braintree",
                 route_id: "Red",
                 stops: [^jfk, ^north_quincy, ^wollaston]
               }
             ] = route_segments
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

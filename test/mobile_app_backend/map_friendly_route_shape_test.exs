defmodule MobileAppBackend.MapFriendlyRouteShapeTest do
  use ExUnit.Case, async: true
  alias MobileAppBackend.MapFriendlyRouteShape
  alias MobileAppBackend.RouteSegment

  import MobileAppBackend.Factory

  describe "non_overlapping_segments/3" do
    test "groups route segments by route_pattern id and associates with shape" do
      %{stop_ids: rp1_segment1_stop_ids} =
        rp1_segment1 = %RouteSegment{
          id: "rp1s1",
          source_route_pattern_id: "rp1",
          source_route_id: "RL",
          stop_ids: ["rp1_segment1_stop1", "rp1_segment1_stop2"]
        }

      %{stop_ids: rp1_segment2_stop_ids} =
        rp1_segment2 = %RouteSegment{
          id: "rp1s2",
          source_route_pattern_id: "rp1",
          source_route_id: "RL",
          stop_ids: ["rp1_segment2_stop1", "rp1_segment2_stop2"]
        }

      %{stop_ids: rp2_segment1_stop_ids} =
        rp2_segment1 = %RouteSegment{
          id: "rp2s1",
          source_route_pattern_id: "rp2",
          source_route_id: "OL",
          stop_ids: ["rp2_segment1_stop1", "rp2_segment1_stop2"]
        }

      rp1 = build(:route_pattern, %{id: "rp1", representative_trip_id: "rp1_trip", sort_order: 2})
      rp2 = build(:route_pattern, %{id: "rp2", representative_trip_id: "rp2_trip", sort_order: 1})

      rp1_trip = build(:trip, %{id: "rp1_trip", shape_id: "rp1_shape"})
      rp2_trip = build(:trip, %{id: "rp2_trip", shape_id: "rp2_shape"})

      rp1_shape = build(:shape, %{id: "rp1_shape"})
      rp2_shape = build(:shape, %{id: "rp2_shape"})

      assert [
               %MapFriendlyRouteShape{
                 source_route_pattern_id: "rp2",
                 source_route_id: "OL",
                 shape: ^rp2_shape,
                 route_segments: [
                   %{
                     stop_ids: ^rp2_segment1_stop_ids
                   }
                 ]
               },
               %MapFriendlyRouteShape{
                 source_route_pattern_id: "rp1",
                 source_route_id: "RL",
                 shape: ^rp1_shape,
                 route_segments: [
                   %{
                     stop_ids: ^rp1_segment1_stop_ids
                   },
                   %{
                     stop_ids: ^rp1_segment2_stop_ids
                   }
                 ]
               }
             ] =
               MapFriendlyRouteShape.from_segments(
                 [rp1_segment1, rp2_segment1, rp1_segment2],
                 %{
                   rp1.id => rp1,
                   rp2.id => rp2
                 },
                 %{
                   rp1_trip.id => rp1_trip,
                   rp2_trip.id => rp2_trip
                 },
                 %{
                   rp1_shape.id => rp1_shape,
                   rp2_shape.id => rp2_shape
                 }
               )
    end
  end
end

defmodule MobileAppBackend.MapFriendlyRouteShapeTest do
  use ExUnit.Case, async: true
  alias MobileAppBackend.MapFriendlyRouteShape
  alias MobileAppBackend.RouteSegment

  import MobileAppBackend.Factory

  describe "non_overlapping_segments/3" do
    test "groups route segments by route_pattern id and associates with shape" do
      rl = build(:route, id: "RL", color: "red_color")
      ol = build(:route, id: "OL", color: "orange_color")

      rp1_segment1 = %RouteSegment{
        id: "rp1s1",
        source_route_pattern_id: "rp1",
        route_id: "RL",
        stops: [build(:stop, id: "rp1_segment1_stop1"), build(:stop, id: "rp1_segment1_stop2")]
      }

      rp1_segment2 = %RouteSegment{
        id: "rp1s2",
        source_route_pattern_id: "rp1",
        route_id: "RL",
        stops: [build(:stop, id: "rp1_segment2_stop1"), build(:stop, id: "rp1_segment2_stop2")]
      }

      rp2_segment1 = %RouteSegment{
        id: "rp2s1",
        source_route_pattern_id: "rp2",
        route_id: "OL",
        stops: [build(:stop, id: "rp2_segment1_stop1"), build(:stop, id: "rp2_segment1_stop2")]
      }

      rp1 = build(:route_pattern, %{id: "rp1", representative_trip_id: "rp1_trip"})
      rp2 = build(:route_pattern, %{id: "rp2", representative_trip_id: "rp2_trip"})

      rp1_trip = build(:trip, %{id: "rp1_trip", shape_id: "rp1_shape"})
      rp2_trip = build(:trip, %{id: "rp2_trip", shape_id: "rp2_shape"})

      rp1_shape = build(:shape, %{id: "rp1_shape"})
      rp2_shape = build(:shape, %{id: "rp2_shape"})

      assert [
               %MapFriendlyRouteShape{
                 route_pattern_id: "rp1",
                 shape: ^rp1_shape,
                 color: "red_color",
                 route_segments: [
                   %{
                     first_stop: %{id: "rp1_segment1_stop1"},
                     last_stop: %{id: "rp1_segment1_stop2"}
                   },
                   %{
                     first_stop: %{id: "rp1_segment2_stop1"},
                     last_stop: %{id: "rp1_segment2_stop2"}
                   }
                 ]
               },
               %MapFriendlyRouteShape{
                 route_pattern_id: "rp2",
                 shape: ^rp2_shape,
                 color: "orange_color",
                 route_segments: [
                   %{
                     first_stop: %{id: "rp2_segment1_stop1"},
                     last_stop: %{id: "rp2_segment1_stop2"}
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
                 %{rl.id => rl, ol.id => ol},
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

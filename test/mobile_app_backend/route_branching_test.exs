defmodule MobileAppBackend.RouteBranchingTest do
  use ExUnit.Case, async: true

  import MobileAppBackend.Factory

  alias MBTAV3API.JsonApi.Object
  alias MobileAppBackend.RouteBranching
  alias MobileAppBackend.RouteBranching.Segment
  alias MobileAppBackend.RouteBranching.Segment.BranchStop
  alias MobileAppBackend.RouteBranching.Segment.StickState

  @empty %Segment.StickSideState{
    before: false,
    converging: false,
    current_stop: false,
    diverging: false,
    after: false
  }
  @forward %Segment.StickSideState{
    before: true,
    converging: false,
    current_stop: true,
    diverging: false,
    after: true
  }
  @skip %{@forward | current_stop: false}

  describe "calculate/4" do
    test "parallel segments work" do
      route = build(:route)
      [a, b, c, d] = build_list(4, :stop)
      trip1 = build(:trip, stop_ids: [a.id, b.id, d.id])
      trip2 = build(:trip, stop_ids: [a.id, c.id, d.id])

      pattern1 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip1.id
        )

      pattern2 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip2.id
        )

      objects = Object.to_full_map([route, a, b, c, d, trip1, trip2, pattern1, pattern2])

      {_, _, segments} =
        RouteBranching.calculate(
          route.id,
          pattern1.direction_id,
          [a.id, b.id, c.id, d.id],
          objects
        )

      assert segments == [
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: a.id,
                     stick_state: %StickState{
                       left: %{@skip | before: false, diverging: true},
                       right: %{@forward | before: false, diverging: true}
                     }
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: b.id,
                     stick_state: %StickState{left: @skip, right: @forward}
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: c.id,
                     stick_state: %StickState{left: @forward, right: @skip}
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: d.id,
                     stick_state: %StickState{
                       left: %{@skip | converging: true, after: false},
                       right: %{@forward | converging: true, after: false}
                     }
                   }
                 ],
                 typical?: true
               }
             ]
    end

    test "Red Line works" do
      alewife = build(:stop)
      trunk_interior = build_list(11, :stop)
      jfk = build(:stop)
      ashmont_interior = build_list(3, :stop)
      ashmont = build(:stop, name: "Ashmont")
      braintree_interior = build_list(4, :stop)
      braintree = build(:stop, name: "Braintree")

      route =
        build(:route, direction_destinations: ["Ashmont/Braintree", "Alewife"], type: :heavy_rail)

      trunk_ids = [alewife.id] ++ Enum.map(trunk_interior, & &1.id) ++ [jfk.id]
      ashmont_ids = Enum.map(ashmont_interior, & &1.id) ++ [ashmont.id]
      braintree_ids = Enum.map(braintree_interior, & &1.id) ++ [braintree.id]
      t1 = build(:trip, stop_ids: trunk_ids ++ ashmont_ids)
      t2 = build(:trip, stop_ids: trunk_ids ++ braintree_ids)

      p1 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: t1.id
        )

      p2 =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: t2.id
        )

      global_data =
        Object.to_full_map(
          trunk_interior ++
            ashmont_interior ++
            braintree_interior ++ [alewife, jfk, ashmont, braintree, route, t1, t2, p1, p2]
        )

      {_, _, segments} =
        RouteBranching.calculate(
          route.id,
          0,
          trunk_ids ++ ashmont_ids ++ braintree_ids,
          global_data
        )

      assert segments == [
               %Segment{
                 name: nil,
                 stops:
                   [
                     %BranchStop{
                       stop_id: alewife.id,
                       stick_state: %StickState{left: @empty, right: %{@forward | before: false}}
                     }
                   ] ++
                     Enum.map(
                       trunk_interior,
                       &%BranchStop{
                         stop_id: &1.id,
                         stick_state: %StickState{left: @empty, right: @forward}
                       }
                     ) ++
                     [
                       %BranchStop{
                         stop_id: jfk.id,
                         stick_state: %StickState{
                           left: %{@skip | before: false, diverging: true},
                           right: %{@forward | diverging: true}
                         }
                       }
                     ],
                 typical?: true
               },
               %Segment{
                 name: "Ashmont",
                 stops:
                   Enum.map(
                     ashmont_interior,
                     &%BranchStop{
                       stop_id: &1.id,
                       stick_state: %StickState{left: @skip, right: @forward}
                     }
                   ) ++
                     [
                       %BranchStop{
                         stop_id: ashmont.id,
                         stick_state: %StickState{left: @skip, right: %{@forward | after: false}}
                       }
                     ],
                 typical?: true
               },
               %Segment{
                 name: "Braintree",
                 stops:
                   Enum.map(
                     braintree_interior,
                     &%BranchStop{
                       stop_id: &1.id,
                       stick_state: %StickState{left: @forward, right: @empty}
                     }
                   ) ++
                     [
                       %BranchStop{
                         stop_id: braintree.id,
                         stick_state: %StickState{left: %{@forward | after: false}, right: @empty}
                       }
                     ],
                 typical?: true
               }
             ]
    end

    test "Foxboro Event Service branch naming works" do
      # not replicating the entire data set for Foxboro
      route =
        build(:route,
          type: :commuter_rail,
          long_name: "Foxboro Event Service",
          direction_destinations: ["Foxboro or Providence", "South Station or Foxboro"]
        )

      south_station = build(:stop, name: "South Station")
      foxboro = build(:stop, name: "Foxboro")
      providence = build(:stop, name: "Providence")

      t1 = build(:trip, direction_id: 0, stop_ids: [south_station.id, foxboro.id])
      t2 = build(:trip, direction_id: 0, stop_ids: [south_station.id, providence.id])
      t3 = build(:trip, direction_id: 1, stop_ids: [providence.id, south_station.id])
      t4 = build(:trip, direction_id: 1, stop_ids: [providence.id, foxboro.id])

      p1 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          typicality: :typical,
          representative_trip_id: t1.id
        )

      p2 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 0,
          typicality: :typical,
          representative_trip_id: t2.id
        )

      p3 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 1,
          typicality: :typical,
          representative_trip_id: t3.id
        )

      p4 =
        build(:route_pattern,
          route_id: route.id,
          direction_id: 1,
          typicality: :typical,
          representative_trip_id: t4.id
        )

      stop_ids = [south_station.id, foxboro.id, providence.id]

      global_data =
        Object.to_full_map([
          route,
          south_station,
          foxboro,
          providence,
          t1,
          t2,
          t3,
          t4,
          p1,
          p2,
          p3,
          p4
        ])

      assert {_, _,
              [
                %Segment{name: "South Station"},
                %Segment{name: "Foxboro"},
                %Segment{name: "Providence"}
              ]} = RouteBranching.calculate(route.id, 0, stop_ids, global_data)

      assert {_, _,
              [
                %Segment{name: "Providence"},
                %Segment{name: "Foxboro"},
                %Segment{name: "South Station"}
              ]} = RouteBranching.calculate(route.id, 1, Enum.reverse(stop_ids), global_data)
    end
  end
end

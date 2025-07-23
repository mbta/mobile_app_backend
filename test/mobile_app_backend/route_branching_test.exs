defmodule MobileAppBackend.RouteBranchingTest do
  use ExUnit.Case, async: true

  import MobileAppBackend.Factory

  alias MBTAV3API.JsonApi.Object
  alias MobileAppBackend.RouteBranching
  alias MobileAppBackend.RouteBranching.Segment
  alias MobileAppBackend.RouteBranching.Segment.BranchStop
  alias MobileAppBackend.RouteBranching.Segment.StickConnection

  defp forward(s1, s2, s3, lane) do
    [
      %StickConnection{
        from_stop: s1,
        to_stop: s2,
        from_lane: lane,
        to_lane: lane,
        from_vpos: :top,
        to_vpos: :center
      },
      %StickConnection{
        from_stop: s2,
        to_stop: s3,
        from_lane: lane,
        to_lane: lane,
        from_vpos: :center,
        to_vpos: :bottom
      }
    ]
    |> Enum.reject(&(is_nil(&1.from_stop) or is_nil(&1.to_stop)))
  end

  describe "calculate/4" do
    test "parallel segments work" do
      route = build(:route)
      a = build(:stop, id: "a")
      b = build(:stop, id: "b")
      c = build(:stop, id: "c")
      d = build(:stop, id: "d")
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
                     stop_lane: :center,
                     connections: [
                       %StickConnection{
                         from_stop: a.id,
                         to_stop: b.id,
                         from_lane: :center,
                         to_lane: :left,
                         from_vpos: :center,
                         to_vpos: :bottom
                       },
                       %StickConnection{
                         from_stop: a.id,
                         to_stop: c.id,
                         from_lane: :center,
                         to_lane: :right,
                         from_vpos: :center,
                         to_vpos: :bottom
                       }
                     ]
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: b.id,
                     stop_lane: :left,
                     connections:
                       forward(a.id, b.id, d.id, :left) ++
                         [
                           %StickConnection{
                             from_stop: a.id,
                             to_stop: c.id,
                             from_lane: :right,
                             to_lane: :right,
                             from_vpos: :top,
                             to_vpos: :bottom
                           }
                         ]
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: c.id,
                     stop_lane: :right,
                     connections:
                       forward(a.id, c.id, d.id, :right) ++
                         [
                           %StickConnection{
                             from_stop: b.id,
                             to_stop: d.id,
                             from_lane: :left,
                             to_lane: :left,
                             from_vpos: :top,
                             to_vpos: :bottom
                           }
                         ]
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: d.id,
                     stop_lane: :center,
                     connections: [
                       %StickConnection{
                         from_stop: b.id,
                         to_stop: d.id,
                         from_lane: :left,
                         to_lane: :center,
                         from_vpos: :top,
                         to_vpos: :center
                       },
                       %StickConnection{
                         from_stop: c.id,
                         to_stop: d.id,
                         from_lane: :right,
                         to_lane: :center,
                         from_vpos: :top,
                         to_vpos: :center
                       }
                     ]
                   }
                 ],
                 typical?: true
               }
             ]
    end

    test "Red Line works" do
      alewife = build(:stop, id: "place-alfcl")
      trunk_interior = build_list(11, :stop)
      jfk = build(:stop, id: "place-jfk")
      savin_hill = build(:stop, id: "place-shmnl")
      ashmont_interior = build_list(2, :stop)
      ashmont = build(:stop, id: "place-asmnl", name: "Ashmont")
      north_quincy = build(:stop, id: "place-nqncy")
      braintree_interior = build_list(3, :stop)
      braintree = build(:stop, id: "place-brntn", name: "Braintree")

      route =
        build(:route, direction_destinations: ["Ashmont/Braintree", "Alewife"], type: :heavy_rail)

      trunk_ids = [alewife.id] ++ Enum.map(trunk_interior, & &1.id) ++ [jfk.id]

      ashmont_ids = [savin_hill.id] ++ Enum.map(ashmont_interior, & &1.id) ++ [ashmont.id]

      braintree_ids = [north_quincy.id] ++ Enum.map(braintree_interior, & &1.id) ++ [braintree.id]

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
            braintree_interior ++
            [alewife, jfk, savin_hill, ashmont, north_quincy, braintree, route, t1, t2, p1, p2]
        )

      {_, _, segments} =
        RouteBranching.calculate(
          route.id,
          0,
          trunk_ids ++ ashmont_ids ++ braintree_ids,
          global_data
        )

      jfk_to_north_quincy_skip = %StickConnection{
        from_stop: jfk.id,
        to_stop: north_quincy.id,
        from_lane: :right,
        to_lane: :right,
        from_vpos: :top,
        to_vpos: :bottom
      }

      assert segments == [
               %Segment{
                 name: nil,
                 stops:
                   [
                     %BranchStop{
                       stop_id: alewife.id,
                       stop_lane: :center,
                       connections:
                         forward(nil, alewife.id, List.first(trunk_interior).id, :center)
                     }
                   ] ++
                     Enum.with_index(
                       trunk_interior,
                       fn stop, index ->
                         %BranchStop{
                           stop_id: stop.id,
                           stop_lane: :center,
                           connections:
                             forward(
                               Enum.at(trunk_ids, index),
                               stop.id,
                               Enum.at(trunk_ids, index + 2),
                               :center
                             )
                         }
                       end
                     ) ++
                     [
                       %BranchStop{
                         stop_id: jfk.id,
                         stop_lane: :center,
                         connections: [
                           %StickConnection{
                             from_stop: List.last(trunk_interior).id,
                             to_stop: jfk.id,
                             from_lane: :center,
                             to_lane: :center,
                             from_vpos: :top,
                             to_vpos: :center
                           },
                           %StickConnection{
                             from_stop: jfk.id,
                             to_stop: north_quincy.id,
                             from_lane: :center,
                             to_lane: :right,
                             from_vpos: :center,
                             to_vpos: :bottom
                           },
                           %StickConnection{
                             from_stop: jfk.id,
                             to_stop: savin_hill.id,
                             from_lane: :center,
                             to_lane: :left,
                             from_vpos: :center,
                             to_vpos: :bottom
                           }
                         ]
                       }
                     ],
                 typical?: true
               },
               %Segment{
                 name: "Ashmont",
                 stops:
                   [
                     %BranchStop{
                       stop_id: savin_hill.id,
                       stop_lane: :left,
                       connections:
                         forward(jfk.id, savin_hill.id, List.first(ashmont_interior).id, :left) ++
                           [jfk_to_north_quincy_skip]
                     }
                   ] ++
                     Enum.with_index(
                       ashmont_interior,
                       fn stop, index ->
                         %BranchStop{
                           stop_id: stop.id,
                           stop_lane: :left,
                           connections:
                             forward(
                               Enum.at(ashmont_ids, index),
                               stop.id,
                               Enum.at(ashmont_ids, index + 2),
                               :left
                             ) ++ [jfk_to_north_quincy_skip]
                         }
                       end
                     ) ++
                     [
                       %BranchStop{
                         stop_id: ashmont.id,
                         stop_lane: :left,
                         connections:
                           forward(List.last(ashmont_interior).id, ashmont.id, nil, :left) ++
                             [jfk_to_north_quincy_skip]
                       }
                     ],
                 typical?: true
               },
               %Segment{
                 name: "Braintree",
                 stops:
                   [
                     %BranchStop{
                       stop_id: north_quincy.id,
                       stop_lane: :right,
                       connections:
                         forward(
                           jfk.id,
                           north_quincy.id,
                           List.first(braintree_interior).id,
                           :right
                         )
                     }
                   ] ++
                     Enum.with_index(
                       braintree_interior,
                       fn stop, index ->
                         %BranchStop{
                           stop_id: stop.id,
                           stop_lane: :right,
                           connections:
                             forward(
                               Enum.at(braintree_ids, index),
                               stop.id,
                               Enum.at(braintree_ids, index + 2),
                               :right
                             )
                         }
                       end
                     ) ++
                     [
                       %BranchStop{
                         stop_id: braintree.id,
                         stop_lane: :right,
                         connections:
                           forward(List.last(braintree_interior).id, braintree.id, nil, :right)
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

    test "fallback works" do
      # simplest failure case is a cycle
      route = build(:route)
      a = build(:stop, id: "a")
      b = build(:stop, id: "b")
      trip1 = build(:trip, stop_ids: [a.id, b.id])
      trip2 = build(:trip, stop_ids: [b.id, a.id])

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

      objects = Object.to_full_map([route, a, b, trip1, trip2, pattern1, pattern2])

      {{stop_graph, segment_graph, segments}, log} =
        ExUnit.CaptureLog.with_log(fn ->
          RouteBranching.calculate(route.id, pattern1.direction_id, [a.id, b.id], objects)
        end)

      assert :digraph.info(stop_graph)
      assert is_nil(segment_graph)

      assert segments == [
               %Segment{
                 stops: [
                   %BranchStop{stop_id: a.id, stop_lane: :center, connections: []},
                   %BranchStop{stop_id: b.id, stop_lane: :center, connections: []}
                 ],
                 name: nil,
                 typical?: true
               }
             ]

      assert log =~ "[error] Stop graph contains cycle"
    end
  end
end

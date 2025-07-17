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

    test "Providence/Stoughton Line works" do
      south = build(:stop)
      back_bay = build(:stop)
      ruggles = build(:stop)
      forest_hills = build(:stop)
      hyde_park = build(:stop)
      readville = build(:stop)
      route128 = build(:stop)
      canton_junction = build(:stop)
      canton_center = build(:stop)
      stoughton = build(:stop, name: "Stoughton")
      sharon = build(:stop)
      mansfield = build(:stop)
      attleboro = build(:stop)
      south_attleboro = build(:stop)
      pawtucket = build(:stop)
      providence = build(:stop, name: "Providence")
      tf_green_airport = build(:stop)
      wickford_junction = build(:stop)
      route = build(:route, type: :commuter_rail, long_name: "Providence/Stoughton Line")

      # rare stops are Forest Hills (f), Hyde Park (h), Readville (r), South Attleboro (s)

      trip_providence_hr =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            hyde_park.id,
            readville.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id
          ]
        )

      trip_providence =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id
          ]
        )

      trip_providence_s =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            south_attleboro.id,
            pawtucket.id,
            providence.id
          ]
        )

      trip_providence_r =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            readville.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id
          ]
        )

      trip_providence_fhr =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            forest_hills.id,
            hyde_park.id,
            readville.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id
          ]
        )

      trip_providence_fh =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            forest_hills.id,
            hyde_park.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id
          ]
        )

      trip_stoughton_typical =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            route128.id,
            canton_junction.id,
            canton_center.id,
            stoughton.id
          ]
        )

      trip_stoughton_h =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            hyde_park.id,
            route128.id,
            canton_junction.id,
            canton_center.id,
            stoughton.id
          ]
        )

      trip_stoughton_hr =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            hyde_park.id,
            readville.id,
            route128.id,
            canton_junction.id,
            canton_center.id,
            stoughton.id
          ]
        )

      trip_stoughton_canonical =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            forest_hills.id,
            hyde_park.id,
            route128.id,
            canton_junction.id,
            canton_center.id,
            stoughton.id
          ]
        )

      trip_wickford_junction_typical =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id,
            tf_green_airport.id,
            wickford_junction.id
          ]
        )

      trip_wickford_junction_s =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            south_attleboro.id,
            pawtucket.id,
            providence.id,
            tf_green_airport.id,
            wickford_junction.id
          ]
        )

      trip_wickford_junction_h =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            hyde_park.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id,
            tf_green_airport.id,
            wickford_junction.id
          ]
        )

      trip_wickford_junction_skip_canton_s =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            south_attleboro.id,
            pawtucket.id,
            providence.id,
            tf_green_airport.id,
            wickford_junction.id
          ]
        )

      trip_wickford_junction_skip_canton =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            pawtucket.id,
            providence.id,
            tf_green_airport.id,
            wickford_junction.id
          ]
        )

      trip_wickford_junction_canonical =
        build(:trip,
          stop_ids: [
            south.id,
            back_bay.id,
            ruggles.id,
            forest_hills.id,
            hyde_park.id,
            route128.id,
            canton_junction.id,
            sharon.id,
            mansfield.id,
            attleboro.id,
            south_attleboro.id,
            pawtucket.id,
            providence.id,
            tf_green_airport.id,
            wickford_junction.id
          ]
        )

      pattern_providence_hr =
        build(:route_pattern,
          route_id: route.id,
          typicality: :deviation,
          representative_trip_id: trip_providence_hr.id
        )

      pattern_providence =
        build(:route_pattern,
          route_id: route.id,
          typicality: :deviation,
          representative_trip_id: trip_providence.id
        )

      pattern_providence_s =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_providence_s.id
        )

      pattern_providence_r =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_providence_r.id
        )

      pattern_providence_fhr =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_providence_fhr.id
        )

      pattern_providence_fh =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_providence_fh.id
        )

      pattern_stoughton_typical =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip_stoughton_typical.id
        )

      pattern_stoughton_h =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_stoughton_h.id
        )

      pattern_stoughton_hr =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_stoughton_hr.id
        )

      pattern_stoughton_canonical =
        build(:route_pattern,
          route_id: route.id,
          typicality: :canonical_only,
          representative_trip_id: trip_stoughton_canonical.id
        )

      pattern_wickford_junction_typical =
        build(:route_pattern,
          route_id: route.id,
          typicality: :typical,
          representative_trip_id: trip_wickford_junction_typical.id
        )

      pattern_wickford_junction_s =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_wickford_junction_s.id
        )

      pattern_wickford_junction_h =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_wickford_junction_h.id
        )

      pattern_wickford_junction_skip_canton_s =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_wickford_junction_skip_canton_s.id
        )

      pattern_wickford_junction_skip_canton =
        build(:route_pattern,
          route_id: route.id,
          typicality: :atypical,
          representative_trip_id: trip_wickford_junction_skip_canton.id
        )

      pattern_wickford_junction_canonical =
        build(:route_pattern,
          route_id: route.id,
          typicality: :canonical_only,
          representative_trip_id: trip_wickford_junction_canonical.id
        )

      stop_ids = [
        south.id,
        back_bay.id,
        ruggles.id,
        hyde_park.id,
        readville.id,
        route128.id,
        canton_junction.id,
        canton_center.id,
        stoughton.id,
        sharon.id,
        mansfield.id,
        attleboro.id,
        south_attleboro.id,
        pawtucket.id,
        providence.id,
        tf_green_airport.id,
        wickford_junction.id
      ]

      global_data =
        Object.to_full_map([
          south,
          back_bay,
          ruggles,
          forest_hills,
          hyde_park,
          readville,
          route128,
          canton_junction,
          canton_center,
          stoughton,
          sharon,
          mansfield,
          attleboro,
          south_attleboro,
          pawtucket,
          providence,
          tf_green_airport,
          wickford_junction,
          route,
          trip_providence_hr,
          trip_providence,
          trip_providence_s,
          trip_providence_r,
          trip_providence_fhr,
          trip_providence_fh,
          trip_stoughton_typical,
          trip_stoughton_h,
          trip_stoughton_hr,
          trip_stoughton_canonical,
          trip_wickford_junction_typical,
          trip_wickford_junction_s,
          trip_wickford_junction_h,
          trip_wickford_junction_skip_canton_s,
          trip_wickford_junction_skip_canton,
          trip_wickford_junction_canonical,
          pattern_providence_hr,
          pattern_providence,
          pattern_providence_s,
          pattern_providence_r,
          pattern_providence_fhr,
          pattern_providence_fh,
          pattern_stoughton_typical,
          pattern_stoughton_h,
          pattern_stoughton_hr,
          pattern_stoughton_canonical,
          pattern_wickford_junction_typical,
          pattern_wickford_junction_s,
          pattern_wickford_junction_h,
          pattern_wickford_junction_skip_canton_s,
          pattern_wickford_junction_skip_canton,
          pattern_wickford_junction_canonical
        ])

      {_, _, segments} = RouteBranching.calculate(route.id, 0, stop_ids, global_data)

      assert segments == [
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: south.id,
                     stick_state: %StickState{left: @empty, right: %{@forward | before: false}}
                   },
                   %BranchStop{
                     stop_id: back_bay.id,
                     stick_state: %StickState{left: @empty, right: @forward}
                   },
                   %BranchStop{
                     stop_id: ruggles.id,
                     stick_state: %StickState{left: @empty, right: @forward}
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: hyde_park.id,
                     stick_state: %StickState{left: @empty, right: @forward}
                   },
                   %BranchStop{
                     stop_id: readville.id,
                     stick_state: %StickState{left: @empty, right: @forward}
                   }
                 ],
                 typical?: false
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: route128.id,
                     stick_state: %StickState{left: @empty, right: @forward}
                   },
                   %BranchStop{
                     stop_id: canton_junction.id,
                     stick_state: %StickState{
                       left: %{@skip | before: false, diverging: true},
                       right: %{@forward | diverging: true}
                     }
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: "Stoughton",
                 stops: [
                   %BranchStop{
                     stop_id: canton_center.id,
                     stick_state: %StickState{left: @skip, right: @forward}
                   },
                   %BranchStop{
                     stop_id: stoughton.id,
                     stick_state: %StickState{left: @skip, right: %{@forward | after: false}}
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: sharon.id,
                     stick_state: %StickState{left: @forward, right: @empty}
                   },
                   %BranchStop{
                     stop_id: mansfield.id,
                     stick_state: %StickState{left: @forward, right: @empty}
                   },
                   %BranchStop{
                     stop_id: attleboro.id,
                     stick_state: %StickState{left: @forward, right: @empty}
                   }
                 ],
                 typical?: true
               },
               %Segment{
                 name: nil,
                 stops: [
                   %BranchStop{
                     stop_id: south_attleboro.id,
                     stick_state: %StickState{left: @forward, right: @empty}
                   }
                 ],
                 typical?: false
               },
               %Segment{
                 name: "Providence",
                 stops: [
                   %BranchStop{
                     stop_id: pawtucket.id,
                     stick_state: %StickState{left: @forward, right: @empty}
                   },
                   %BranchStop{
                     stop_id: providence.id,
                     stick_state: %StickState{left: @forward, right: @empty}
                   },
                   %BranchStop{
                     stop_id: tf_green_airport.id,
                     stick_state: %StickState{left: @forward, right: @empty}
                   },
                   %BranchStop{
                     stop_id: wickford_junction.id,
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

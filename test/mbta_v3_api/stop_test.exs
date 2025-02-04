defmodule MBTAV3API.StopTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Stop
  import MobileAppBackend.Factory

  test "parse!/1" do
    assert Stop.parse!(%JsonApi.Item{
             type: "stop",
             id: "70158",
             attributes: %{
               "latitude" => 42.352531,
               "longitude" => -71.064682,
               "name" => "Boylston",
               "location_type" => 0
             },
             relationships: %{
               "parent_station" => %JsonApi.Reference{type: "stop", id: "place-boyls"}
             }
           }) == %Stop{
             id: "70158",
             latitude: 42.352531,
             longitude: -71.064682,
             name: "Boylston",
             location_type: :stop,
             parent_station_id: "place-boyls"
           }

    assert Stop.parse!(%JsonApi.Item{
             type: "stop",
             id: "70158",
             attributes: %{
               "latitude" => 42.352531,
               "longitude" => -71.064682,
               "name" => "Boylston",
               "location_type" => 0
             },
             relationships: %{
               "parent_station" => %JsonApi.Reference{
                 type: "stop",
                 id: "place-boyls"
               }
             }
           }) == %Stop{
             id: "70158",
             latitude: 42.352531,
             longitude: -71.064682,
             name: "Boylston",
             location_type: :stop,
             parent_station_id: "place-boyls"
           }
  end

  describe "parent_id/1" do
    test "works on a child stop" do
      assert Stop.parent_id(%Stop{id: "child", parent_station_id: "parent"}) == "parent"
    end

    test "works on a non-child stop" do
      assert Stop.parent_id(%Stop{id: "stop", parent_station_id: nil}) == "stop"
    end
  end

  describe "parent_if_exists/2" do
    test "when a child stop and parent is in the map then return the parent" do
      child = build(:stop, parent_station_id: "parentId")
      parent = build(:stop, id: child.parent_station_id, location_type: :station)
      assert parent == Stop.parent_if_exists(child, %{parent.id => parent, child.id => child})
    end

    test "when a child stop and parent is in not in the map then return the child" do
      child = build(:stop, parent_station_id: "parentId")
      assert child == Stop.parent_if_exists(child, %{child.id => child})
    end

    test "when a child stop and no parent then return the child" do
      child = build(:stop, parent_station_id: nil)
      assert child == Stop.parent_if_exists(child, %{child.id => child})
    end
  end

  describe "stop_id_to_children/2" do
    test "returns only the given stop ids with their :stop children" do
      other_stop = build(:stop, id: "other")
      standalone = build(:stop, id: "standalone")
      child_stop = build(:stop, id: "child_stop", location_type: :stop)
      node_stop = build(:stop, id: "child_node", location_type: :generic_node)

      parent_stop =
        build(:stop,
          id: "parent",
          location_type: :station,
          child_stop_ids: ["child_stop", "child_node", "child_missing"]
        )

      assert %{"parent" => ["child_stop"], "standalone" => []} ==
               Stop.stop_id_to_children(
                 %{
                   other_stop.id => other_stop,
                   standalone.id => standalone,
                   child_stop.id => child_stop,
                   node_stop.id => node_stop,
                   parent_stop.id => parent_stop
                 },
                 ["standalone", "parent"]
               )
    end
  end

  describe "include_missing_siblings/1" do
    test "sibling stops which aren't included in the stop map are added to the stop map" do
      stops_with_missing_sibling = %{
        "BNT-0000-05" => %Stop{
          id: "BNT-0000-05",
          latitude: 42.366618,
          longitude: -71.062601,
          name: "North Station",
          location_type: :stop,
          parent_station_id: "place-north",
          child_stop_ids: nil
        }
      }

      extra_stops = %{
        "place-north" => %Stop{
          id: "place-north",
          latitude: 42.365577,
          longitude: -71.06129,
          name: "North Station",
          location_type: :station,
          parent_station_id: nil,
          child_stop_ids: ["70206", "BNT-0000", "BNT-0000-01", "door-north-causewaye"]
        },
        "70206" => %Stop{
          id: "70206",
          latitude: 42.36528,
          longitude: -71.060205,
          name: "North Station",
          location_type: :stop,
          parent_station_id: "place-north",
          child_stop_ids: nil
        },
        "BNT-0000" => %Stop{
          id: "BNT-0000",
          latitude: 42.366417,
          longitude: -71.062326,
          name: "North Station",
          location_type: :stop,
          parent_station_id: "place-north",
          child_stop_ids: nil
        },
        "BNT-0000-01" => %Stop{
          id: "BNT-0000-01",
          latitude: 42.366493,
          longitude: -71.062829,
          name: "North Station",
          location_type: :stop,
          parent_station_id: "place-north",
          child_stop_ids: nil
        },
        "door-north-causewaye" => %Stop{
          id: "door-north-causewaye",
          latitude: 42.365639,
          longitude: -71.060472,
          name: "North Station - Causeway St (Elevator)",
          location_type: :generic_node
        }
      }

      assert %{
               "BNT-0000-05" => %Stop{
                 id: "BNT-0000-05",
                 parent_station_id: "place-north"
               },
               "70206" => %Stop{
                 id: "70206",
                 latitude: 42.36528,
                 longitude: -71.060205,
                 parent_station_id: "place-north",
                 child_stop_ids: nil
               },
               "BNT-0000" => %Stop{
                 id: "BNT-0000",
                 latitude: 42.366417,
                 longitude: -71.062326,
                 parent_station_id: "place-north",
                 child_stop_ids: nil
               },
               "BNT-0000-01" => %Stop{
                 id: "BNT-0000-01",
                 latitude: 42.366493,
                 longitude: -71.062829,
                 parent_station_id: "place-north",
                 child_stop_ids: nil
               }
             } =
               Stop.include_missing_siblings(stops_with_missing_sibling, extra_stops)
    end
  end
end

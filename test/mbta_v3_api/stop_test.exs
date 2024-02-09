defmodule MBTAV3API.StopTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Stop

  test "parse/1" do
    assert Stop.parse(%JsonApi.Item{
             type: "stop",
             id: "70158",
             attributes: %{
               "latitude" => 42.352531,
               "longitude" => -71.064682,
               "name" => "Boylston",
               "location_type" => 0
             },
             relationships: %{
               "parent_station" => [
                 %JsonApi.Item{
                   type: "stop",
                   id: "place-boyls",
                   attributes: %{
                     "latitude" => 42.35302,
                     "longitude" => -71.06459,
                     "name" => "Boylston",
                     "location_type" => 0
                   }
                 }
               ]
             }
           }) == %Stop{
             id: "70158",
             latitude: 42.352531,
             longitude: -71.064682,
             name: "Boylston",
             location_type: :stop,
             parent_station: %Stop{
               id: "place-boyls",
               latitude: 42.35302,
               longitude: -71.06459,
               name: "Boylston",
               location_type: :stop
             }
           }

    assert Stop.parse(%JsonApi.Item{
             type: "stop",
             id: "70158",
             attributes: %{
               "latitude" => 42.352531,
               "longitude" => -71.064682,
               "name" => "Boylston",
               "location_type" => 0
             },
             relationships: %{
               "parent_station" => [
                 %JsonApi.Reference{
                   type: "stop",
                   id: "place-boyls"
                 }
               ]
             }
           }) == %Stop{
             id: "70158",
             latitude: 42.352531,
             longitude: -71.064682,
             name: "Boylston",
             location_type: :stop,
             parent_station: %JsonApi.Reference{
               type: "stop",
               id: "place-boyls"
             }
           }
  end

  describe "parent/1" do
    test "works on a child stop" do
      assert Stop.parent(%Stop{id: "child", parent_station: %Stop{id: "parent"}}) == %Stop{
               id: "parent"
             }
    end

    test "throws on a child stop with an un-included parent" do
      assert_raise FunctionClauseError, fn ->
        Stop.parent(%Stop{
          id: "child",
          parent_station: %JsonApi.Reference{type: "stop", id: "parent"}
        })
      end
    end

    test "works on a non-child stop" do
      assert Stop.parent(%Stop{id: "stop"}) == %Stop{id: "stop"}
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
          parent_station: %Stop{
            id: "place-north",
            latitude: 42.365577,
            longitude: -71.06129,
            name: "North Station",
            location_type: :station,
            parent_station: nil,
            child_stops: [
              %Stop{
                id: "70206",
                latitude: 42.36528,
                longitude: -71.060205,
                name: "North Station",
                location_type: :stop,
                parent_station: %JsonApi.Reference{
                  type: "stop",
                  id: "place-north"
                },
                child_stops: nil
              },
              %Stop{
                id: "BNT-0000",
                latitude: 42.366417,
                longitude: -71.062326,
                name: "North Station",
                location_type: :stop,
                parent_station: %JsonApi.Reference{
                  type: "stop",
                  id: "place-north"
                },
                child_stops: nil
              },
              %Stop{
                id: "BNT-0000-01",
                latitude: 42.366493,
                longitude: -71.062829,
                name: "North Station",
                location_type: :stop,
                parent_station: %JsonApi.Reference{
                  type: "stop",
                  id: "place-north"
                },
                child_stops: nil
              },
              %Stop{
                id: "door-north-causewaye",
                latitude: 42.365639,
                longitude: -71.060472,
                name: "North Station - Causeway St (Elevator)",
                location_type: :generic_node
              }
            ]
          },
          child_stops: nil
        }
      }

      assert %{
               "BNT-0000-05" => %Stop{
                 id: "BNT-0000-05",
                 parent_station: %Stop{
                   id: "place-north",
                   name: "North Station",
                   location_type: :station,
                   parent_station: nil,
                   child_stops: nil
                 }
               },
               "70206" => %Stop{
                 id: "70206",
                 latitude: 42.36528,
                 longitude: -71.060205,
                 parent_station: %Stop{
                   id: "place-north",
                   name: "North Station",
                   location_type: :station,
                   parent_station: nil,
                   child_stops: nil
                 },
                 child_stops: nil
               },
               "BNT-0000" => %Stop{
                 id: "BNT-0000",
                 latitude: 42.366417,
                 longitude: -71.062326,
                 parent_station: %Stop{
                   id: "place-north",
                   child_stops: nil
                 },
                 child_stops: nil
               },
               "BNT-0000-01" => %Stop{
                 id: "BNT-0000-01",
                 latitude: 42.366493,
                 longitude: -71.062829,
                 parent_station: %Stop{
                   id: "place-north",
                   child_stops: nil
                 },
                 child_stops: nil
               }
             } =
               Stop.include_missing_siblings(stops_with_missing_sibling)
    end
  end
end

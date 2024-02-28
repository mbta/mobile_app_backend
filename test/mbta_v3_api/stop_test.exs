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
end

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
               "name" => "Boylston"
             },
             relationships: %{
               "parent_station" => [
                 %JsonApi.Item{
                   type: "stop",
                   id: "place-boyls",
                   attributes: %{
                     "latitude" => 42.35302,
                     "longitude" => -71.06459,
                     "name" => "Boylston"
                   }
                 }
               ]
             }
           }) == %Stop{
             id: "70158",
             latitude: 42.352531,
             longitude: -71.064682,
             name: "Boylston",
             parent_station: %Stop{
               id: "place-boyls",
               latitude: 42.35302,
               longitude: -71.06459,
               name: "Boylston"
             }
           }

    assert Stop.parse(%JsonApi.Item{
             type: "stop",
             id: "70158",
             attributes: %{
               "latitude" => 42.352531,
               "longitude" => -71.064682,
               "name" => "Boylston"
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
end
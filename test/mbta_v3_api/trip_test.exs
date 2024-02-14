defmodule MBTAV3API.TripTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Trip

  test "parse/1" do
    assert %Trip{
             id: "60451275",
             headsign: "Wakefield Ave",
             route_pattern: %JsonApi.Reference{type: "route_pattern", id: "24-2-0"},
             stops: [
               %JsonApi.Reference{type: "stop", id: "334"},
               %JsonApi.Reference{type: "stop", id: "536"}
             ]
           } ==
             Trip.parse(%JsonApi.Item{
               id: "60451275",
               attributes: %{
                 "headsign" => "Wakefield Ave"
               },
               relationships: %{
                 "route_pattern" => [
                   %JsonApi.Reference{type: "route_pattern", id: "24-2-0"}
                 ],
                 "stops" => [
                   %JsonApi.Reference{type: "stop", id: "334"},
                   %JsonApi.Reference{type: "stop", id: "536"}
                 ]
               }
             })
  end
end
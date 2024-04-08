defmodule MBTAV3API.TripTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Trip

  test "parse/1" do
    assert %Trip{
             id: "60451275",
             direction_id: 0,
             headsign: "Wakefield Ave",
             route_pattern_id: "24-2-0",
             stop_ids: ["334", "536"]
           } ==
             Trip.parse(%JsonApi.Item{
               id: "60451275",
               attributes: %{
                 "direction_id" => 0,
                 "headsign" => "Wakefield Ave"
               },
               relationships: %{
                 "route_pattern" => %JsonApi.Reference{type: "route_pattern", id: "24-2-0"},
                 "stops" => [
                   %JsonApi.Reference{type: "stop", id: "334"},
                   %JsonApi.Reference{type: "stop", id: "536"}
                 ]
               }
             })
  end
end

defmodule MBTAV3API.VehicleTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Vehicle

  test "parse/1" do
    assert %Vehicle{
             id: "y1886",
             bearing: 315,
             current_status: :in_transit_to,
             direction_id: 0,
             latitude: 42.359901428222656,
             longitude: -71.09449005126953,
             route_id: "1",
             stop_id: "99",
             trip_id: "61391720"
           } ==
             Vehicle.parse(%JsonApi.Item{
               type: "vehicle",
               id: "y1886",
               attributes: %{
                 "bearing" => 315,
                 "current_status" => "IN_TRANSIT_TO",
                 "direction_id" => 0,
                 "latitude" => 42.359901428222656,
                 "longitude" => -71.09449005126953
               },
               relationships: %{
                 "route" => %JsonApi.Reference{type: "route", id: "1"},
                 "stop" => %JsonApi.Reference{type: "stop", id: "99"},
                 "trip" => %JsonApi.Reference{type: "trip", id: "61391720"}
               }
             })
  end
end

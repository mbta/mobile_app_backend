defmodule MBTAV3API.VehicleTest do
  use ExUnit.Case, async: true

  import Test.Support.Sigils
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
             occupancy_status: :many_seats_available,
             route_id: "1",
             stop_id: "99",
             trip_id: "61391720",
             updated_at: ~B[2024-01-24 17:08:51]
           } ==
             Vehicle.parse(%JsonApi.Item{
               type: "vehicle",
               id: "y1886",
               attributes: %{
                 "bearing" => 315,
                 "current_status" => "IN_TRANSIT_TO",
                 "occupancy_status" => "MANY_SEATS_AVAILABLE",
                 "direction_id" => 0,
                 "latitude" => 42.359901428222656,
                 "longitude" => -71.09449005126953,
                 "updated_at" => "2024-01-24T17:08:51-05:00"
               },
               relationships: %{
                 "route" => %JsonApi.Reference{type: "route", id: "1"},
                 "stop" => %JsonApi.Reference{type: "stop", id: "99"},
                 "trip" => %JsonApi.Reference{type: "trip", id: "61391720"}
               }
             })
  end

  test "parse/1 with nil occupancy status" do
    assert %Vehicle{
             id: "y1886",
             bearing: 315,
             current_status: :in_transit_to,
             direction_id: 0,
             latitude: 42.359901428222656,
             longitude: -71.09449005126953,
             occupancy_status: :no_data_available,
             route_id: "1",
             stop_id: "99",
             trip_id: "61391720",
             updated_at: ~B[2024-01-24 17:08:51]
           } ==
             Vehicle.parse(%JsonApi.Item{
               type: "vehicle",
               id: "y1886",
               attributes: %{
                 "bearing" => 315,
                 "current_status" => "IN_TRANSIT_TO",
                 "occupancy_status" => nil,
                 "direction_id" => 0,
                 "latitude" => 42.359901428222656,
                 "longitude" => -71.09449005126953,
                 "updated_at" => "2024-01-24T17:08:51-05:00"
               },
               relationships: %{
                 "route" => %JsonApi.Reference{type: "route", id: "1"},
                 "stop" => %JsonApi.Reference{type: "stop", id: "99"},
                 "trip" => %JsonApi.Reference{type: "trip", id: "61391720"}
               }
             })
  end
end

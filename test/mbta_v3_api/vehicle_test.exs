defmodule MBTAV3API.VehicleTest do
  use ExUnit.Case, async: true

  import Test.Support.Sigils
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Vehicle
  alias MBTAV3API.Vehicle.Carriage

  test "parse!/1" do
    assert %Vehicle{
             id: "y1886",
             bearing: 315,
             carriages: nil,
             current_status: :in_transit_to,
             current_stop_sequence: 30,
             decoration: nil,
             direction_id: 0,
             latitude: 42.359901428222656,
             longitude: -71.09449005126953,
             occupancy_status: :many_seats_available,
             route_id: "1",
             stop_id: "99",
             trip_id: "61391720",
             updated_at: ~B[2024-01-24 17:08:51]
           } ==
             Vehicle.parse!(%JsonApi.Item{
               type: "vehicle",
               id: "y1886",
               attributes: %{
                 "bearing" => 315,
                 "current_status" => "IN_TRANSIT_TO",
                 "current_stop_sequence" => 30,
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

  test "parse!/1 with nil occupancy status" do
    assert %Vehicle{
             id: "y1886",
             bearing: 315,
             carriages: nil,
             current_status: :in_transit_to,
             current_stop_sequence: 99,
             decoration: nil,
             direction_id: 0,
             latitude: 42.359901428222656,
             longitude: -71.09449005126953,
             occupancy_status: :no_data_available,
             route_id: "1",
             stop_id: "99",
             trip_id: "61391720",
             updated_at: ~B[2024-01-24 17:08:51]
           } ==
             Vehicle.parse!(%JsonApi.Item{
               type: "vehicle",
               id: "y1886",
               attributes: %{
                 "bearing" => 315,
                 "current_status" => "IN_TRANSIT_TO",
                 "current_stop_sequence" => 99,
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

  test "parse!/1 with nil direction_id" do
    assert_raise RuntimeError, "vehicle has nil direction_id", fn ->
      Vehicle.parse!(%JsonApi.Item{
        type: "vehicle",
        id: "y1886",
        attributes: %{
          "bearing" => 315,
          "current_status" => "IN_TRANSIT_TO",
          "current_stop_sequence" => 30,
          "occupancy_status" => "MANY_SEATS_AVAILABLE",
          "direction_id" => nil,
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

  test "parse!/1 handles carriages" do
    assert %Vehicle{
             id: "O-5486F65F",
             bearing: 175,
             carriages: [
               %Carriage{
                 label: "1520",
                 occupancy_status: :few_seats_available,
                 occupancy_percentage: 14
               },
               %Carriage{
                 label: "1521",
                 occupancy_status: :few_seats_available,
                 occupancy_percentage: 17
               },
               %Carriage{
                 label: "1467",
                 occupancy_status: :few_seats_available,
                 occupancy_percentage: 12
               },
               %Carriage{
                 label: "1466",
                 occupancy_status: :standing_room_only,
                 occupancy_percentage: 28
               },
               %Carriage{
                 label: "1499",
                 occupancy_status: :not_accepting_passengers,
                 occupancy_percentage: nil
               },
               %Carriage{
                 label: "1498",
                 occupancy_status: :standing_room_only,
                 occupancy_percentage: 25
               }
             ],
             current_status: :stopped_at,
             current_stop_sequence: 80,
             decoration: nil,
             direction_id: 0,
             latitude: 42.35881,
             longitude: -71.05782,
             occupancy_status: :no_data_available,
             updated_at: ~B[2025-12-15 14:42:25],
             route_id: "Orange",
             stop_id: "70022",
             trip_id: "NONREV-1580723414"
           } ==
             Vehicle.parse!(%JsonApi.Item{
               type: "vehicle",
               id: "O-5486F65F",
               attributes: %{
                 "bearing" => 175,
                 "carriages" => [
                   %{
                     "label" => "1520",
                     "occupancy_status" => "FEW_SEATS_AVAILABLE",
                     "occupancy_percentage" => 14
                   },
                   %{
                     "label" => "1521",
                     "occupancy_status" => "FEW_SEATS_AVAILABLE",
                     "occupancy_percentage" => 17
                   },
                   %{
                     "label" => "1467",
                     "occupancy_status" => "FEW_SEATS_AVAILABLE",
                     "occupancy_percentage" => 12
                   },
                   %{
                     "label" => "1466",
                     "occupancy_status" => "STANDING_ROOM_ONLY",
                     "occupancy_percentage" => 28
                   },
                   %{
                     "label" => "1499",
                     "occupancy_status" => "NOT_ACCEPTING_PASSENGERS",
                     "occupancy_percentage" => nil
                   },
                   %{
                     "label" => "1498",
                     "occupancy_status" => "STANDING_ROOM_ONLY",
                     "occupancy_percentage" => 25
                   }
                 ],
                 "current_status" => "STOPPED_AT",
                 "current_stop_sequence" => 80,
                 "direction_id" => 0,
                 "latitude" => 42.35881,
                 "longitude" => -71.05782,
                 "occupancy_status" => nil,
                 "updated_at" => "2025-12-15T14:42:25-05:00"
               },
               relationships: %{
                 "route" => %JsonApi.Reference{type: "route", id: "Orange"},
                 "stop" => %JsonApi.Reference{type: "stop", id: "70022"},
                 "trip" => %JsonApi.Reference{type: "trip", id: "NONREV-1580723414"}
               }
             })
  end

  test "parse!/1 finds decorations" do
    required_attributes = %{
      "current_status" => "IN_TRANSIT_TO",
      "direction_id" => 0,
      "updated_at" => "2025-12-15T14:42:25-05:00"
    }

    assert %Vehicle{decoration: :pride} =
             Vehicle.parse!(%JsonApi.Item{id: "y1833", attributes: required_attributes})

    assert %Vehicle{decoration: :pride} =
             Vehicle.parse!(%JsonApi.Item{
               id: "G-1",
               attributes:
                 Map.put(required_attributes, "carriages", [
                   %{"label" => "3900"},
                   %{"label" => "3706"}
                 ])
             })

    assert %Vehicle{decoration: nil} =
             Vehicle.parse!(%JsonApi.Item{
               id: "O-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "3706"}])
             })

    assert %Vehicle{decoration: :winter_holiday} =
             Vehicle.parse!(%JsonApi.Item{
               id: "G-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "3908"}])
             })

    assert %Vehicle{decoration: :winter_holiday} =
             Vehicle.parse!(%JsonApi.Item{
               id: "G-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "3917"}])
             })

    assert %Vehicle{decoration: :winter_holiday} =
             Vehicle.parse!(%JsonApi.Item{
               id: "O-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "1524"}])
             })

    assert %Vehicle{decoration: :googly_eyes} =
             Vehicle.parse!(%JsonApi.Item{
               id: "G-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "3639"}])
             })

    assert %Vehicle{decoration: :googly_eyes} =
             Vehicle.parse!(%JsonApi.Item{
               id: "G-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "3864"}])
             })

    assert %Vehicle{decoration: :googly_eyes} =
             Vehicle.parse!(%JsonApi.Item{
               id: "G-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "3909"}])
             })

    assert %Vehicle{decoration: :googly_eyes} =
             Vehicle.parse!(%JsonApi.Item{
               id: "G-1",
               attributes: Map.put(required_attributes, "carriages", [%{"label" => "3918"}])
             })

    assert %Vehicle{decoration: :googly_eyes} =
             Vehicle.parse!(%JsonApi.Item{id: "1035", attributes: required_attributes})
  end
end

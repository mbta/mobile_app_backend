defmodule MBTAV3API.PredictionTest do
  use ExUnit.Case, async: true

  import Test.Support.Sigils
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction

  test "parse/1" do
    assert Prediction.parse(%JsonApi.Item{
             id: "prediction-ADDED-1591587107-70237-440",
             attributes: %{
               "arrival_time" => "2024-01-24T17:08:51-05:00",
               "departure_time" => nil,
               "direction_id" => 0,
               "schedule_relationship" => "ADDED",
               "status" => nil,
               "stop_sequence" => 440
             },
             relationships: %{
               "route" => [%JsonApi.Reference{id: "Green-C", type: "route"}],
               "stop" => [%JsonApi.Reference{id: "70237", type: "stop"}],
               "trip" => [%JsonApi.Reference{id: "ADDED-1591587107", type: "trip"}],
               "vehicle" => [%JsonApi.Reference{id: "G-10070", type: "vehicle"}]
             }
           }) == %Prediction{
             id: "prediction-ADDED-1591587107-70237-440",
             arrival_time: ~B[2024-01-24 17:08:51],
             departure_time: nil,
             direction_id: 0,
             revenue: true,
             schedule_relationship: :added,
             status: nil,
             stop_sequence: 440,
             stop: %JsonApi.Reference{type: "stop", id: "70237"},
             trip: %JsonApi.Reference{type: "trip", id: "ADDED-1591587107"},
             vehicle: %JsonApi.Reference{type: "vehicle", id: "G-10070"}
           }
  end
end

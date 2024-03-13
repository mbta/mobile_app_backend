defmodule MBTAV3API.ScheduleTest do
  use ExUnit.Case, async: true
  import Test.Support.Sigils
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Schedule

  test "parse/1" do
    assert Schedule.parse(%JsonApi.Item{
             type: "schedule",
             id: "schedule-60565179-70159-90",
             attributes: %{
               "arrival_time" => "2024-03-13T01:07:00-04:00",
               "departure_time" => "2024-03-13T01:07:00-04:00",
               "drop_off_type" => 0,
               "pickup_type" => 0,
               "stop_sequence" => 90
             },
             relationships: %{
               "route" => %JsonApi.Reference{type: "route", id: "Green-D"},
               "stop" => %JsonApi.Reference{type: "stop", id: "70159"},
               "trip" => %JsonApi.Reference{type: "trip", id: "60565179"}
             }
           }) == %Schedule{
             id: "schedule-60565179-70159-90",
             arrival_time: ~B[2024-03-13 01:07:00],
             departure_time: ~B[2024-03-13 01:07:00],
             drop_off_type: :regular,
             pick_up_type: :regular,
             stop_sequence: 90,
             stop_id: "70159",
             trip_id: "60565179"
           }
  end
end

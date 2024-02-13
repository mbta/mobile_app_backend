defmodule MBTAV3API.RoutePatternTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.RoutePattern

  test "parse/1" do
    assert RoutePattern.parse(%JsonApi.Item{
             id: "Green-C-832-1",
             attributes: %{
               "direction_id" => 1,
               "name" => "Cleveland Circle - Government Center",
               "sort_order" => 100_331_000
             },
             relationships: %{
               "route" => [
                 %JsonApi.Item{type: "route", id: "Green-C"}
               ],
               "representative_trip" => [
                 %JsonApi.Item{type: "trip", id: "trip123"}
               ]
             }
           }) == %RoutePattern{
             id: "Green-C-832-1",
             direction_id: 1,
             name: "Cleveland Circle - Government Center",
             sort_order: 100_331_000,
             route: %MBTAV3API.Route{id: "Green-C"},
             representative_trip: %MBTAV3API.Trip{id: "trip123"}
           }
  end
end

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
               "sort_order" => 100_331_000,
               "typicality" => 1
             },
             relationships: %{
               "route" => %JsonApi.Reference{type: "route", id: "Green-C"},
               "representative_trip" => %JsonApi.Reference{type: "trip", id: "trip123"}
             }
           }) == %RoutePattern{
             id: "Green-C-832-1",
             direction_id: 1,
             name: "Cleveland Circle - Government Center",
             sort_order: 100_331_000,
             typicality: :typical,
             route_id: "Green-C",
             representative_trip_id: "trip123"
           }
  end
end

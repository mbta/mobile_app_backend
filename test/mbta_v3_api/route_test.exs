defmodule MBTAV3API.RouteTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Route

  test "parse/1" do
    assert Route.parse(%JsonApi.Item{
             id: "Green-C",
             attributes: %{
               "color" => "00843D",
               "direction_destinations" => ["Cleveland Circle", "Government Center"],
               "direction_names" => ["West", "East"],
               "long_name" => "Green Line C",
               "short_name" => "C",
               "sort_order" => 10_033,
               "text_color" => "FFFFFF"
             }
           }) == %Route{
             id: "Green-C",
             color: "00843D",
             direction_destinations: ["Cleveland Circle", "Government Center"],
             direction_names: ["West", "East"],
             long_name: "Green Line C",
             short_name: "C",
             sort_order: 10_033,
             text_color: "FFFFFF"
           }
  end
end

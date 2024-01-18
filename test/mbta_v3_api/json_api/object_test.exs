defmodule MBTAV3API.JsonApi.ObjectTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi.Object

  test "put_fields" do
    assert Object.put_fields([include: :parent_station], :stop) |> Enum.sort() == [
             "fields[stop]": "latitude,longitude,name",
             include: :parent_station
           ]

    assert Object.put_fields([include: :route], :route_pattern) |> Enum.sort() == [
             "fields[route]":
               "color,direction_names,direction_destinations,long_name,short_name,sort_order,text_color",
             "fields[route_pattern]": "direction_id,name,sort_order",
             include: :route
           ]
  end
end

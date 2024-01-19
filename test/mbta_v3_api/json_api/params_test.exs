defmodule MBTAV3API.JsonApi.ParamsTest do
  use ExUnit.Case, async: true
  doctest MBTAV3API.JsonApi.Params

  describe "flatten_params/1" do
    import MBTAV3API.JsonApi.Params, only: [flatten_params: 2]

    test "sort works" do
      refute Map.has_key?(flatten_params([], :stop), "sort")
      assert %{"sort" => "name"} = flatten_params([sort: {:name, :asc}], :trip)
      assert %{"sort" => "-id"} = flatten_params([sort: {:id, :desc}], :route)
    end

    test "fields work" do
      assert %{"fields[stop]" => "latitude,longitude,name"} = flatten_params([], :stop)

      assert %{
               "fields[route]" =>
                 "color,direction_names,direction_destinations,long_name,short_name,sort_order,text_color",
               "fields[route_pattern]" => "direction_id,name,sort_order"
             } =
               flatten_params([include: :route], :route_pattern)

      assert %{
               "fields[route_pattern]" => "direction_id,name,sort_order",
               "fields[trip]" => "asdf,ghjk"
             } =
               flatten_params(
                 [include: :representative_trip, fields: [trip: [:asdf, :ghjk]]],
                 :route_pattern
               )
    end

    test "include works" do
      refute Map.has_key?(flatten_params([], :trip), "include")

      assert %{"include" => "parent_station"} = flatten_params([include: :parent_station], :stop)

      assert %{"include" => "route,representative_trip,representative_trip.stops"} =
               flatten_params([include: [:route, representative_trip: :stops]], :route_pattern)
    end

    test "filter works" do
      assert %{"filter[abc]" => "123,45.67,abc,def"} =
               flatten_params([filter: [abc: [123, 45.67, :abc, "def"]]], :stop)
    end
  end
end

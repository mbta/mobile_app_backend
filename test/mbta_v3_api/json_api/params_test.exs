defmodule MBTAV3API.JsonApi.ParamsTest do
  use ExUnit.Case, async: true
  doctest MBTAV3API.JsonApi.Params

  describe "flatten_params/1" do
    import MBTAV3API.JsonApi.Params, only: [flatten_params: 2]

    test "does not sort if no sort given" do
      refute Map.has_key?(flatten_params([], MBTAV3API.Stop), "sort")
    end

    test "sorts ascending" do
      assert %{"sort" => "name"} = flatten_params([sort: {:name, :asc}], MBTAV3API.Trip)
    end

    test "sorts descending" do
      assert %{"sort" => "-id"} = flatten_params([sort: {:id, :desc}], MBTAV3API.Route)
    end

    test "uses fields for type if no includes or overrides" do
      assert %{"fields[stop]" => "latitude,longitude,name,location_type"} =
               flatten_params([], MBTAV3API.Stop)
    end

    test "uses fields for included type" do
      assert %{
               "fields[route]" =>
                 "type,color,direction_names,direction_destinations,long_name,short_name,sort_order,text_color",
               "fields[route_pattern]" => "canonical,direction_id,name,sort_order,typicality"
             } =
               flatten_params([include: :route], MBTAV3API.RoutePattern)
    end

    test "can override fields" do
      assert %{
               "fields[route_pattern]" => "canonical,direction_id,name,sort_order,typicality",
               "fields[trip]" => "asdf,ghjk"
             } =
               flatten_params(
                 [include: :representative_trip, fields: [trip: [:asdf, :ghjk]]],
                 MBTAV3API.RoutePattern
               )
    end

    test "does not include if no include given" do
      refute Map.has_key?(flatten_params([], MBTAV3API.Trip), "include")
    end

    test "includes single related object" do
      assert %{"include" => "parent_station"} =
               flatten_params([include: :parent_station], MBTAV3API.Stop)
    end

    test "handles nested includes" do
      assert %{"include" => "route,representative_trip,representative_trip.stops"} =
               flatten_params(
                 [include: [:route, representative_trip: :stops]],
                 MBTAV3API.RoutePattern
               )
    end

    test "filter works" do
      assert %{"filter[abc]" => "123,45.67,abc,def"} =
               flatten_params([filter: [abc: [123, 45.67, :abc, "def"]]], MBTAV3API.Stop)
    end

    test "uses custom serialize for filter" do
      assert %{"filter[route_type]" => "0,4", "filter[location_type]" => "0,1"} =
               flatten_params(
                 [filter: [route_type: [:light_rail, :ferry], location_type: [:stop, :station]]],
                 MBTAV3API.Stop
               )
    end
  end
end

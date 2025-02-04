defmodule MBTAV3API.RouteTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Route

  describe "parse!/1" do
    test "parse route only" do
      assert Route.parse!(%JsonApi.Item{
               id: "Green-C",
               attributes: %{
                 "color" => "00843D",
                 "direction_destinations" => ["Cleveland Circle", "Government Center"],
                 "direction_names" => ["West", "East"],
                 "long_name" => "Green Line C",
                 "short_name" => "C",
                 "sort_order" => 10_033,
                 "text_color" => "FFFFFF",
                 "type" => 0
               },
               relationships: %{
                 "line" => %JsonApi.Reference{type: "line", id: "line-Green"}
               }
             }) == %Route{
               id: "Green-C",
               color: "00843D",
               direction_destinations: ["Cleveland Circle", "Government Center"],
               direction_names: ["West", "East"],
               long_name: "Green Line C",
               short_name: "C",
               sort_order: 10_033,
               text_color: "FFFFFF",
               type: :light_rail,
               line_id: "line-Green"
             }
    end

    test "parse with included line overrides route color" do
      assert %Route{
               id: "orange-shuttle",
               color: "line_color",
               direction_destinations: ["Oak Grove", "Forest Hills"],
               direction_names: ["Northbound", "Southbound"],
               long_name: "Orange Line Shuttle",
               short_name: "OL Shuttle",
               sort_order: 123,
               text_color: "line_text_color",
               type: :bus,
               line_id: "line-Orange"
             } ==
               Route.parse!(
                 %JsonApi.Item{
                   id: "orange-shuttle",
                   attributes: %{
                     "color" => "bus_color",
                     "direction_destinations" => ["Oak Grove", "Forest Hills"],
                     "direction_names" => ["Northbound", "Southbound"],
                     "long_name" => "Orange Line Shuttle",
                     "short_name" => "OL Shuttle",
                     "sort_order" => 123,
                     "text_color" => "bus_text_color",
                     "type" => 3
                   },
                   relationships: %{
                     "line" => %JsonApi.Reference{type: "line", id: "line-Orange"}
                   }
                 },
                 [
                   %JsonApi.Item{
                     type: "line",
                     id: "line-Orange",
                     attributes: %{
                       "color" => "line_color",
                       "text_color" => "line_text_color"
                     }
                   }
                 ]
               )
    end
  end
end

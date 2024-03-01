defmodule MBTAV3API.Stream.StateTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MBTAV3API.Stream.State
  alias ServerSentEventStage.Event

  describe "apply_events/2" do
    test "adds" do
      green_b = %Route{
        id: "Green-B",
        color: "00843D",
        direction_destinations: ["Boston College", "Government Center"],
        direction_names: ["West", "East"],
        long_name: "Green Line B",
        short_name: "B",
        sort_order: 10_032,
        text_color: "FFFFFF"
      }

      state = JsonApi.Object.to_full_map([green_b])

      assert State.apply_events(state, [
               %Event{
                 event: "add",
                 data:
                   ~s({"attributes":{"direction_id":0,"name":"Government Center - Boston College","sort_order":100320000,"typicality":1},"id":"Green-B-812-0","relationships":{"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"})
               }
             ]) ==
               JsonApi.Object.to_full_map([
                 green_b,
                 %RoutePattern{
                   id: "Green-B-812-0",
                   direction_id: 0,
                   name: "Government Center - Boston College",
                   sort_order: 100_320_000,
                   typicality: :typical,
                   representative_trip_id: nil,
                   route_id: "Green-B"
                 }
               ])
    end

    test "removes" do
      state =
        JsonApi.Object.to_full_map([
          %Stop{
            id: "place-boyls",
            latitude: 42.35302,
            longitude: -71.06459,
            name: "Boylston",
            parent_station_id: nil
          }
        ])

      assert State.apply_events(state, [
               %Event{event: "remove", data: ~s({"id":"place-boyls","type":"stop"})}
             ]) == JsonApi.Object.to_full_map([])
    end

    test "updates" do
      state =
        JsonApi.Object.to_full_map([
          %Stop{
            id: "place-boyls",
            latitude: 42.35302,
            longitude: -71.06459,
            name: "Boylston",
            parent_station_id: nil
          }
        ])

      assert State.apply_events(state, [
               %Event{
                 event: "update",
                 data:
                   ~s({"attributes":{"latitude":-42.35302,"location_type":3,"longitude":71.06459,"name":"Not Boylston"},"id":"place-boyls","type":"stop"})
               }
             ]) ==
               JsonApi.Object.to_full_map([
                 %Stop{
                   id: "place-boyls",
                   latitude: -42.35302,
                   longitude: 71.06459,
                   name: "Not Boylston",
                   location_type: :generic_node,
                   parent_station_id: nil
                 }
               ])
    end

    test "resets" do
      state =
        JsonApi.Object.to_full_map([
          %Stop{
            id: "place-boyls",
            latitude: 42.35302,
            location_type: :station,
            longitude: -71.06459,
            name: "Boylston",
            parent_station_id: nil
          }
        ])

      assert State.apply_events(state, [
               %Event{
                 event: "reset",
                 data:
                   ~s([{"attributes":{"latitude":42.377359,"location_type":1,"longitude":-71.094761,"name":"Union Square"},"id":"place-unsqu","type":"stop"}])
               }
             ]) ==
               JsonApi.Object.to_full_map([
                 %Stop{
                   id: "place-unsqu",
                   latitude: 42.377359,
                   longitude: -71.094761,
                   name: "Union Square",
                   location_type: :station,
                   parent_station_id: nil
                 }
               ])
    end
  end
end

defmodule MBTAV3API.Stream.StateTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MBTAV3API.Stream.State
  alias ServerSentEventStage.Event

  describe "apply_events/2" do
    test "adds, resolving references" do
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

      state =
        State.new()
        |> put_in([Route, "Green-B"], green_b)

      assert State.apply_events(state, [
               %Event{
                 event: "add",
                 data:
                   ~s({"attributes":{"direction_id":0,"name":"Government Center - Boston College","sort_order":100320000},"id":"Green-B-812-0","relationships":{"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"})
               }
             ]) == %State{
               data: %{
                 Route => %{"Green-B" => green_b},
                 RoutePattern => %{
                   "Green-B-812-0" => %RoutePattern{
                     id: "Green-B-812-0",
                     direction_id: 0,
                     name: "Government Center - Boston College",
                     sort_order: 100_320_000,
                     representative_trip: nil,
                     route: green_b
                   }
                 }
               }
             }
    end

    test "removes" do
      state =
        State.new()
        |> put_in([Stop, "place-boyls"], %Stop{
          id: "place-boyls",
          latitude: 42.35302,
          longitude: -71.06459,
          name: "Boylston",
          parent_station: nil
        })

      assert State.apply_events(state, [
               %Event{event: "remove", data: ~s({"id":"place-boyls","type":"stop"})}
             ]) == %State{data: %{Stop => %{}}}
    end

    test "updates" do
      state =
        State.new()
        |> put_in([Stop, "place-boyls"], %Stop{
          id: "place-boyls",
          latitude: 42.35302,
          longitude: -71.06459,
          name: "Boylston",
          parent_station: nil
        })

      assert State.apply_events(state, [
               %Event{
                 event: "update",
                 data:
                   ~s({"attributes":{"latitude":-42.35302,"longitude":71.06459,"name":"Not Boylston"},"id":"place-boyls","type":"stop"})
               }
             ]) == %State{
               data: %{
                 Stop => %{
                   "place-boyls" => %Stop{
                     id: "place-boyls",
                     latitude: -42.35302,
                     longitude: 71.06459,
                     name: "Not Boylston",
                     parent_station: nil
                   }
                 }
               }
             }
    end

    test "resets" do
      state =
        State.new()
        |> put_in([Stop, "place-boyls"], %Stop{
          id: "place-boyls",
          latitude: 42.35302,
          longitude: -71.06459,
          name: "Boylston",
          parent_station: nil
        })

      assert State.apply_events(state, [
               %Event{
                 event: "reset",
                 data:
                   ~s([{"attributes":{"latitude":42.377359,"longitude":-71.094761,"name":"Union Square"},"id":"place-unsqu","type":"stop"}])
               }
             ]) == %State{
               data: %{
                 Stop => %{
                   "place-unsqu" => %Stop{
                     id: "place-unsqu",
                     latitude: 42.377359,
                     longitude: -71.094761,
                     name: "Union Square",
                     parent_station: nil
                   }
                 }
               }
             }
    end
  end
end

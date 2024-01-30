defmodule MBTAV3API.Stream.EventTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stream.Event
  alias ServerSentEventStage.Event, as: RawEvent

  describe "parse/1" do
    test "parses reset" do
      result =
        Event.parse(%RawEvent{
          event: "reset",
          data: """
          [
            {"attributes":{"direction_id":0,"name":"Government Center - Boston College","sort_order":100320000},"id":"Green-B-812-0","links":{"self":"/route_patterns/Green-B-812-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-0","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"},
            {"attributes":{"direction_id":0,"name":"Government Center - Cleveland Circle","sort_order":100330000},"id":"Green-C-832-0","links":{"self":"/route_patterns/Green-C-832-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-C-C1-0","type":"trip"}},"route":{"data":{"id":"Green-C","type":"route"}}},"type":"route_pattern"}
          ]
          """
        })

      assert result == %Event.Reset{
               data: [
                 %RoutePattern{
                   id: "Green-B-812-0",
                   direction_id: 0,
                   name: "Government Center - Boston College",
                   sort_order: 100_320_000,
                   representative_trip: %JsonApi.Reference{
                     type: "trip",
                     id: "canonical-Green-B-C1-0"
                   },
                   route: %JsonApi.Reference{type: "route", id: "Green-B"}
                 },
                 %RoutePattern{
                   id: "Green-C-832-0",
                   direction_id: 0,
                   name: "Government Center - Cleveland Circle",
                   sort_order: 100_330_000,
                   representative_trip: %JsonApi.Reference{
                     type: "trip",
                     id: "canonical-Green-C-C1-0"
                   },
                   route: %JsonApi.Reference{type: "route", id: "Green-C"}
                 }
               ]
             }
    end

    test "parses add" do
      result =
        Event.parse(%RawEvent{
          event: "add",
          data: """
          {"attributes":{"direction_id":1,"name":"Boston College - Government Center","sort_order":100321000},"id":"Green-B-812-1","links":{"self":"/route_patterns/Green-B-812-1"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-1","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"}
          """
        })

      assert result == %Event.Add{
               data: %RoutePattern{
                 id: "Green-B-812-1",
                 direction_id: 1,
                 name: "Boston College - Government Center",
                 sort_order: 100_321_000,
                 representative_trip: %JsonApi.Reference{
                   type: "trip",
                   id: "canonical-Green-B-C1-1"
                 },
                 route: %JsonApi.Reference{type: "route", id: "Green-B"}
               }
             }
    end

    test "parses update" do
      result =
        Event.parse(%RawEvent{
          event: "update",
          data: """
          {"attributes":{"direction_id":0,"name":"Union Square - Riverside","sort_order":100340000},"id":"Green-D-855-0","links":{"self":"/route_patterns/Green-D-855-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-D-C1-0","type":"trip"}},"route":{"data":{"id":"Green-D","type":"route"}}},"type":"route_pattern"}
          """
        })

      assert result == %Event.Update{
               data: %RoutePattern{
                 id: "Green-D-855-0",
                 direction_id: 0,
                 name: "Union Square - Riverside",
                 sort_order: 100_340_000,
                 representative_trip: %JsonApi.Reference{
                   type: "trip",
                   id: "canonical-Green-D-C1-0"
                 },
                 route: %JsonApi.Reference{type: "route", id: "Green-D"}
               }
             }
    end

    test "parses remove" do
      result =
        Event.parse(%RawEvent{
          event: "remove",
          data: """
          {"id":"Green-E-886-0","type":"route_pattern"}
          """
        })

      assert result == %Event.Remove{
               data: %JsonApi.Reference{
                 type: "route_pattern",
                 id: "Green-E-886-0"
               }
             }
    end
  end
end

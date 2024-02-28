defmodule MBTAV3API.Stream.ConsumerTest do
  use ExUnit.Case, async: true

  import Test.Support.Helpers
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stream

  test "parses events and sends messages" do
    {:ok, producer} =
      GenStage.from_enumerable([
        %ServerSentEventStage.Event{
          event: "reset",
          data: """
          [
            {"attributes":{},"id":"Green-B","type":"route"},
            {"attributes":{"direction_id":0,"name":"Government Center - Boston College","sort_order":100320000,"typicality":1},"id":"Green-B-812-0","links":{"self":"/route_patterns/Green-B-812-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-0","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"},
            {"attributes":{"direction_id":0,"name":"Government Center - Cleveland Circle","sort_order":100330000,"typicality":1},"id":"Green-C-832-0","links":{"self":"/route_patterns/Green-C-832-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-C-C1-0","type":"trip"}},"route":{"data":{"id":"Green-C","type":"route"}}},"type":"route_pattern"}
          ]
          """
        },
        %ServerSentEventStage.Event{
          event: "add",
          data: """
          {"attributes":{"direction_id":1,"name":"Boston College - Government Center","sort_order":100321000,"typicality":1},"id":"Green-B-812-1","links":{"self":"/route_patterns/Green-B-812-1"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-1","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"}
          """
        },
        %ServerSentEventStage.Event{
          event: "update",
          data: """
          {"attributes":{"direction_id":1,"name":"Not Government Center - Not Cleveland Circle","sort_order":100330001,"typicality":1},"id":"Green-C-832-0","links":{"self":"/route_patterns/Green-C-832-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-C-C1-0","type":"trip"}},"route":{"data":{"id":"Green-C","type":"route"}}},"type":"route_pattern"}
          """
        },
        %ServerSentEventStage.Event{
          event: "remove",
          data: """
          {"id":"Green-B-812-0","type":"route_pattern"}
          """
        }
      ])

    _consumer =
      start_link_supervised!(
        {Stream.Consumer, subscribe_to: [producer], send_to: self(), type: RoutePattern},
        restart: :transient
      )

    assert_receive {:stream_data, data}

    assert data ==
             to_full_map([
               %Route{id: "Green-B"},
               %RoutePattern{
                 id: "Green-B-812-1",
                 direction_id: 1,
                 name: "Boston College - Government Center",
                 sort_order: 100_321_000,
                 typicality: :typical,
                 representative_trip_id: "canonical-Green-B-C1-1",
                 route_id: "Green-B"
               },
               %RoutePattern{
                 id: "Green-C-832-0",
                 direction_id: 1,
                 name: "Not Government Center - Not Cleveland Circle",
                 sort_order: 100_330_001,
                 typicality: :typical,
                 representative_trip_id: "canonical-Green-C-C1-0",
                 route_id: "Green-C"
               }
             ])
  end
end

defmodule MBTAV3API.Stream.ConsumerTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stream

  test "parses events and sends messages" do
    {:ok, producer} =
      GenStage.from_enumerable([
        %ServerSentEventStage.Event{
          event: "reset",
          data: """
          [
            {"attributes":{"direction_id":0,"name":"Government Center - Boston College","sort_order":100320000},"id":"Green-B-812-0","links":{"self":"/route_patterns/Green-B-812-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-0","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"},
            {"attributes":{"direction_id":0,"name":"Government Center - Cleveland Circle","sort_order":100330000},"id":"Green-C-832-0","links":{"self":"/route_patterns/Green-C-832-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-C-C1-0","type":"trip"}},"route":{"data":{"id":"Green-C","type":"route"}}},"type":"route_pattern"}
          ]
          """
        },
        %ServerSentEventStage.Event{
          event: "add",
          data: """
          {"attributes":{"direction_id":1,"name":"Boston College - Government Center","sort_order":100321000},"id":"Green-B-812-1","links":{"self":"/route_patterns/Green-B-812-1"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-1","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"}
          """
        },
        %ServerSentEventStage.Event{
          event: "update",
          data: """
          {"attributes":{"direction_id":0,"name":"Union Square - Riverside","sort_order":100340000},"id":"Green-D-855-0","links":{"self":"/route_patterns/Green-D-855-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-D-C1-0","type":"trip"}},"route":{"data":{"id":"Green-D","type":"route"}}},"type":"route_pattern"}
          """
        },
        %ServerSentEventStage.Event{
          event: "remove",
          data: """
          {"id":"Green-E-886-0","type":"route_pattern"}
          """
        }
      ])

    _consumer = start_supervised!({Stream.Consumer, subscribe_to: [producer], send_to: self()})

    assert_receive {:stream_events,
                    [
                      %Stream.Event.Reset{data: [%RoutePattern{}, %RoutePattern{}]},
                      %Stream.Event.Add{data: %RoutePattern{}},
                      %Stream.Event.Update{data: %RoutePattern{}},
                      %Stream.Event.Remove{data: %JsonApi.Reference{}}
                    ]}
  end
end

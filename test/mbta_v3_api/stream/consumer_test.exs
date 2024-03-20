defmodule MBTAV3API.Stream.ConsumerTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stream
  alias Test.Support.SSEStub

  describe "parses events and sends messages" do
    def events do
      [
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
      ]
    end

    def expected_data do
      JsonApi.Object.to_full_map([
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

    test "sends directly to pid" do
      {:ok, producer} = GenStage.from_enumerable(events())

      _consumer =
        start_link_supervised!(
          {Stream.Consumer, subscribe_to: [producer], destination: self(), type: RoutePattern},
          restart: :transient
        )

      assert_receive {:stream_data, data}

      assert data == expected_data()
    end

    test "broadcasts over PubSub" do
      topic = "test:abcdefg"
      MBTAV3API.Stream.PubSub.subscribe(topic)

      {:ok, producer} = GenStage.from_enumerable(events())

      _consumer =
        start_link_supervised!(
          {Stream.Consumer, subscribe_to: [producer], destination: topic, type: RoutePattern},
          restart: :transient
        )

      assert_receive {:stream_data, data}

      assert data == expected_data()
    end

    test "remembers state" do
      {:ok, producer} = GenStage.from_enumerable(events())

      consumer =
        start_link_supervised!(
          {Stream.Consumer,
           subscribe_to: [{producer, [cancel: :temporary]}],
           destination: self(),
           type: RoutePattern},
          restart: :transient
        )

      assert_receive {:stream_data, _}

      assert GenServer.call(consumer, :get_data) == expected_data()
    end

    test "throttles new updates" do
      throttle_interval = 25

      producer = start_link_supervised!(SSEStub)

      _consumer =
        start_link_supervised!(
          {Stream.Consumer,
           subscribe_to: [producer],
           destination: self(),
           type: RoutePattern,
           throttle_ms: throttle_interval},
          restart: :transient
        )

      SSEStub.push_events(producer, [Enum.at(events(), 0)])

      assert_receive {:stream_data, _}

      SSEStub.push_events(producer, [Enum.at(events(), 1)])

      refute_receive {:stream_data, _}, throttle_interval - 1
      assert_receive {:stream_data, _}

      SSEStub.push_events(producer, [Enum.at(events(), 2)])
      SSEStub.push_events(producer, [Enum.at(events(), 3)])

      refute_receive {:stream_data, _}, throttle_interval - 1
      assert_receive {:stream_data, final_data}

      assert final_data == expected_data()
    end
  end
end

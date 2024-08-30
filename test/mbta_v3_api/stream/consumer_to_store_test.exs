defmodule Stream.ConsumerToStoreTest do
  use ExUnit.Case
  import Mox

  alias MBTAV3API.JsonApi
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stream

  setup :verify_on_exit!

  describe "parses events and sends messages" do
    def reset_event do
      %ServerSentEventStage.Event{
        event: "reset",
        data: """
        [
          {"attributes":{},"id":"Green-B","type":"route"},
          {"attributes":{"direction_id":0,"name":"Government Center - Boston College","sort_order":100320000,"typicality":1},"id":"Green-B-812-0","links":{"self":"/route_patterns/Green-B-812-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-0","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"},
          {"attributes":{"direction_id":0,"name":"Government Center - Cleveland Circle","sort_order":100330000,"typicality":1},"id":"Green-C-832-0","links":{"self":"/route_patterns/Green-C-832-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-C-C1-0","type":"trip"}},"route":{"data":{"id":"Green-C","type":"route"}}},"type":"route_pattern"}
        ]
        """
      }
    end

    def add_event do
      %ServerSentEventStage.Event{
        event: "add",
        data: """
        {"attributes":{"direction_id":1,"name":"Boston College - Government Center","sort_order":100321000,"typicality":1},"id":"Green-B-812-1","links":{"self":"/route_patterns/Green-B-812-1"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-B-C1-1","type":"trip"}},"route":{"data":{"id":"Green-B","type":"route"}}},"type":"route_pattern"}
        """
      }
    end

    def update_event do
      %ServerSentEventStage.Event{
        event: "update",
        data: """
        {"attributes":{"direction_id":1,"name":"Not Government Center - Not Cleveland Circle","sort_order":100330001,"typicality":1},"id":"Green-C-832-0","links":{"self":"/route_patterns/Green-C-832-0"},"relationships":{"representative_trip":{"data":{"id":"canonical-Green-C-C1-0","type":"trip"}},"route":{"data":{"id":"Green-C","type":"route"}}},"type":"route_pattern"}
        """
      }
    end

    def remove_event do
      %ServerSentEventStage.Event{
        event: "remove",
        data: """
        {"id":"Green-B-812-0","type":"route_pattern"}
        """
      }
    end

    def events do
      [reset_event(), add_event(), update_event(), remove_event()]
    end
  end

  test "sends reset directly to pid" do
    PredictionsStoreMock
    |> expect(:process_reset, fn data, [:route_id, "66"] ->
      assert length(data) == 3
      :ok
    end)

    Stream.ConsumerToStore.handle_events([reset_event()], self(), %{
      store: PredictionsStoreMock,
      destination: self(),
      scope: [:route_id, "66"]
    })

    assert_receive :reset_event
  end

  test "reset event sent to store and broadcast" do
    topic = "test:abcdefg"
    Stream.PubSub.subscribe(topic)

    PredictionsStoreMock
    |> expect(:process_reset, fn data, [:route_id, "66"] ->
      assert length(data) == 3
      :ok
    end)

    Stream.ConsumerToStore.handle_events([reset_event()], self(), %{
      store: PredictionsStoreMock,
      destination: topic,
      scope: [:route_id, "66"]
    })

    assert_receive :reset_event
  end

  test "add event sent to store but not broadcast" do
    topic = "test:abcdefg"
    Stream.PubSub.subscribe(topic)

    PredictionsStoreMock
    |> expect(:process_upsert, fn :add, [%RoutePattern{id: "Green-B-812-1"}] ->
      :ok
    end)

    Stream.ConsumerToStore.handle_events([add_event()], self(), %{
      store: PredictionsStoreMock,
      destination: topic
    })

    refute_receive _
  end

  test "update event sent to store but not broadcast" do
    topic = "test:abcdefg"
    Stream.PubSub.subscribe(topic)

    PredictionsStoreMock
    |> expect(:process_upsert, fn :update, [%RoutePattern{id: "Green-C-832-0"}] ->
      :ok
    end)

    Stream.ConsumerToStore.handle_events([update_event()], self(), %{
      store: PredictionsStoreMock,
      destination: topic
    })

    refute_receive _
  end

  test "remove event sent to store but not broadcast" do
    topic = "test:abcdefg"

    expect(PredictionsStoreMock, :process_remove, fn [%JsonApi.Reference{id: "Green-B-812-0"}] ->
      :ok
    end)

    Stream.PubSub.subscribe(topic)

    Stream.ConsumerToStore.handle_events([remove_event()], self(), %{
      store: PredictionsStoreMock,
      destination: topic
    })

    refute_receive _
  end
end

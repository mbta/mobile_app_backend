defmodule MBTAV3API.Stream.StaticInstanceTest do
  use ExUnit.Case, async: false
  alias MBTAV3API.Stream
  alias Test.Support.FakeStaticInstance

  describe "child_spec/1" do
    test "correctly builds child spec with good options" do
      assert Stream.StaticInstance.child_spec(
               type: MBTAV3API.Trip,
               url: "/trips",
               topic: "some:topic",
               include: :shape,
               filter: [date: ~D[2024-03-14]],
               base_url: "http://example.net",
               api_key: "931"
             ) == %{
               id: {Stream.StaticInstance, "some:topic"},
               restart: :permanent,
               start:
                 {Stream.Instance, :start_link,
                  [
                    [
                      url:
                        "http://example.net/trips?fields%5Bshape%5D=polyline&fields%5Btrip%5D=direction_id%2Cheadsign&filter%5Bdate%5D=2024-03-14&include=shape",
                      headers: [{"x-api-key", "931"}],
                      destination: "some:topic",
                      type: MBTAV3API.Trip,
                      name: {:via, Registry, {Stream.Registry, "some:topic"}},
                      consumer: nil
                    ]
                  ]},
               type: :supervisor
             }
    end

    test "detects missing options" do
      assert_raise KeyError, ~r"key :type not found", fn ->
        Stream.StaticInstance.child_spec(url: "/trips", topic: "some:topic")
      end

      assert_raise KeyError, ~r"key :url not found", fn ->
        Stream.StaticInstance.child_spec(type: MBTAV3API.Trip, topic: "some:topic")
      end

      assert_raise KeyError, ~r"key :topic not found", fn ->
        Stream.StaticInstance.child_spec(type: MBTAV3API.Trip, url: "/trips")
      end
    end

    test "preserves consumer and destination" do
      assert Stream.StaticInstance.child_spec(
               type: MBTAV3API.Trip,
               url: "/trips",
               topic: "some:topic",
               destination: "some:other:topic",
               include: :shape,
               filter: [date: ~D[2024-03-14]],
               base_url: "http://example.net",
               api_key: "931",
               consumer: %{store: :some_store, scope: [route_id: "66"]}
             ) == %{
               id: {Stream.StaticInstance, "some:topic"},
               restart: :permanent,
               start:
                 {Stream.Instance, :start_link,
                  [
                    [
                      url:
                        "http://example.net/trips?fields%5Bshape%5D=polyline&fields%5Btrip%5D=direction_id%2Cheadsign&filter%5Bdate%5D=2024-03-14&include=shape",
                      headers: [{"x-api-key", "931"}],
                      destination: "some:other:topic",
                      type: MBTAV3API.Trip,
                      name: {:via, Registry, {Stream.Registry, "some:topic"}},
                      consumer: %{store: :some_store, scope: [route_id: "66"]}
                    ]
                  ]},
               type: :supervisor
             }
    end
  end

  describe "subscribe/1" do
    test "subscribes and fetches current data" do
      start_link_supervised!({FakeStaticInstance, topic: "test:topic", data: :existing_data})

      assert {:ok, :existing_data} == Stream.StaticInstance.subscribe("test:topic")

      Stream.PubSub.broadcast!("test:topic", :new_data)

      assert_receive :new_data
    end

    test "launches new instance if not already running" do
      topic = "predictions:route:fake-route-that-won't-already-exist"
      refute Stream.Registry.find_pid(topic)
      assert {:ok, _} = Stream.StaticInstance.subscribe(topic)
      assert Stream.Registry.find_pid(topic)
    end

    test "when include_current_data is false, skips returning latest data" do
      start_link_supervised!({FakeStaticInstance, topic: "test:topic", data: :existing_data})

      assert {:ok, :current_data_not_requested} ==
               Stream.StaticInstance.subscribe("test:topic", include_current_data: false)
    end
  end

  describe "ensure_stream_started/1" do
    test "when existing stream, only fetches current data" do
      start_link_supervised!({FakeStaticInstance, topic: "test:topic", data: :existing_data})

      assert {:ok, :existing_data} == Stream.StaticInstance.ensure_stream_started("test:topic")
    end

    test "launches new instance if not already running" do
      topic = "predictions:route:fake-route"
      refute Stream.Registry.find_pid(topic)
      assert {:ok, _} = Stream.StaticInstance.ensure_stream_started(topic)
      assert Stream.Registry.find_pid(topic)
    end

    test "when include_current_data is false, skips returning latest data" do
      start_link_supervised!({FakeStaticInstance, topic: "test:topic", data: :existing_data})

      assert {:ok, :current_data_not_requested} ==
               Stream.StaticInstance.ensure_stream_started("test:topic",
                 include_current_data: false
               )
    end
  end
end

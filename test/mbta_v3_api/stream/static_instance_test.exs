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
                        "http://example.net/trips?fields%5Bshape%5D=polyline&fields%5Btrip%5D=headsign&filter%5Bdate%5D=2024-03-14&include=shape",
                      headers: [{"x-api-key", "931"}],
                      destination: "some:topic",
                      type: MBTAV3API.Trip,
                      name: {:via, Registry, {Stream.Registry, "some:topic"}}
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
  end

  describe "subscribe/1" do
    test "subscribes and fetches current data" do
      start_link_supervised!({FakeStaticInstance, topic: "test:topic", data: :existing_data})

      assert {:ok, :existing_data} == Stream.StaticInstance.subscribe("test:topic")

      Stream.PubSub.broadcast!("test:topic", :new_data)

      assert_receive :new_data
    end

    @tag skip: "has a really annoying race condition with other alerts-stream-based tests"
    test "launches new instance if not already running" do
      assert [] = Supervisor.which_children(Stream.Supervisor)

      refute Stream.Registry.find_pid("alerts")
      assert {:ok, _} = Stream.StaticInstance.subscribe("alerts")
      assert Stream.Registry.find_pid("alerts")

      assert [{_, pid, _, [Stream.Instance]}] = Supervisor.which_children(Stream.Supervisor)
      ref = Process.monitor(pid)
      Stream.Instance.shutdown(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}
    end
  end
end

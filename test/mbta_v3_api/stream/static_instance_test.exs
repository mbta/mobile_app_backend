defmodule MBTAV3API.Stream.StaticInstanceTest do
  use ExUnit.Case, async: true
  alias MBTAV3API.Stream

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
               restart: :transient,
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
      defmodule FakeConsumer do
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, nil, opts)
        end

        @impl true
        def init(_) do
          {:ok, nil}
        end

        @impl true
        def handle_call(:get_data, _from, _state) do
          {:reply, :existing_data, nil}
        end
      end

      _ = start_link_supervised!({FakeConsumer, name: Stream.Registry.via_name("test:topic")})

      assert {:ok, :existing_data} == Stream.StaticInstance.subscribe("test:topic")

      Stream.PubSub.broadcast!("test:topic", :new_data)

      assert_receive :new_data
    end
  end
end

defmodule MobileAppBackendWeb.VehicleChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  alias MBTAV3API.Stream
  alias Test.Support.FakeStaticInstance

  setup do
    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

  test "returns vehicle data on join", %{socket: socket} do
    target = build(:vehicle)
    other = build(:vehicle)

    start_link_supervised!(
      {FakeStaticInstance, topic: "vehicles", data: to_full_map([target, other])}
    )

    {:ok, reply, _socket} = subscribe_and_join(socket, "vehicle:id:#{target.id}")

    assert reply == %{vehicle: target}
  end

  describe "handles incoming vehicles messages" do
    setup %{socket: socket} do
      target = build(:vehicle)
      other = build(:vehicle)

      start_link_supervised!(
        {FakeStaticInstance, topic: "vehicles", data: to_full_map([target, other])}
      )

      {:ok, _reply, _socket} = subscribe_and_join(socket, "vehicle:id:#{target.id}")
      {:ok, %{target: target, other: other}}
    end

    test "returns nil when there is no longer data for the vehicle", %{
      other: other
    } do
      broadcast_vehicles([other])

      assert_push "stream_data", data
      assert %{vehicle: nil} = data
    end

    test "returns updated vehicle", %{target: target, other: other} do
      updated_target = %{target | current_status: :stopped_at}

      broadcast_vehicles([updated_target, other])

      assert_push "stream_data", data
      assert %{vehicle: ^updated_target} = data
    end

    test "when vehicle data hasn't changed, doesn't push", %{target: target} do
      broadcast_vehicles([target])

      refute_push "stream_data", _
    end

    defp broadcast_vehicles(vehicles) do
      Stream.PubSub.broadcast!("vehicles", {:stream_data, "vehicles", to_full_map(vehicles)})
    end
  end
end

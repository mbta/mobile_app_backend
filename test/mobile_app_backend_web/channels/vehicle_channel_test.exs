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
    target_vehicle = build(:vehicle)
    other_vehicle = build(:vehicle)

    start_link_supervised!(
      {FakeStaticInstance, topic: "vehicles", data: to_full_map([target_vehicle, other_vehicle])}
    )

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "vehicle:id:#{target_vehicle.id}")

    assert reply == %{vehicle: target_vehicle}
  end

  test "returns nil when there is no longer data for the vehicle", %{socket: socket} do
    target_vehicle = build(:vehicle)
    other_vehicle = build(:vehicle)

    start_link_supervised!(
      {FakeStaticInstance, topic: "vehicles", data: to_full_map([target_vehicle, other_vehicle])}
    )

    {:ok, _reply, _socket} =
      subscribe_and_join(socket, "vehicle:id:#{target_vehicle.id}")

    Stream.PubSub.broadcast!(
      "vehicles",
      {:stream_data, "vehicles", to_full_map([other_vehicle])}
    )

    assert_push "stream_data", data
    assert %{vehicle: nil} = data
  end

  test "returns updated vehicle", %{socket: socket} do
    target_vehicle = build(:vehicle, current_status: :stopped_at)
    other_vehicle = build(:vehicle)

    start_link_supervised!(
      {FakeStaticInstance, topic: "vehicles", data: to_full_map([target_vehicle, other_vehicle])}
    )

    {:ok, _reply, _socket} =
      subscribe_and_join(socket, "vehicle:id:#{target_vehicle.id}")

    updated_vehicle = %{target_vehicle | current_status: :in_transit_to}

    Stream.PubSub.broadcast!(
      "vehicles",
      {:stream_data, "vehicles", to_full_map([updated_vehicle, other_vehicle])}
    )

    assert_push "stream_data", data
    assert %{vehicle: ^updated_vehicle} = data
  end

  test "when vehicle data hasn't changed, doesn't push", %{socket: socket} do
    target_vehicle = build(:vehicle)
    other_vehicle = build(:vehicle)

    start_link_supervised!(
      {FakeStaticInstance, topic: "vehicles", data: to_full_map([target_vehicle, other_vehicle])}
    )

    {:ok, _reply, _socket} =
      subscribe_and_join(socket, "vehicle:id:#{target_vehicle.id}")

    Stream.PubSub.broadcast!(
      "vehicles",
      {:stream_data, "vehicles", to_full_map([target_vehicle])}
    )

    refute_push "stream_data", _
  end
end

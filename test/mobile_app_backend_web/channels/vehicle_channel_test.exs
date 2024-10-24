defmodule MobileAppBackendWeb.VehicleChannelTest do
  alias MobileAppBackendWeb.VehicleChannel
  use MobileAppBackendWeb.ChannelCase

  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers

  setup do
    reassign_env(:mobile_app_backend, MobileAppBackend.Vehicles.PubSub, VehiclesPubSubMock)

    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

  test "returns vehicle data on join", %{socket: socket} do
    target = build(:vehicle)

    expect(VehiclesPubSubMock, :subscribe, 1, fn _ -> target end)

    {:ok, reply, _socket} = subscribe_and_join(socket, "vehicle:id:#{target.id}")

    assert reply == %{vehicle: target}
  end

  test "handles incoming vehicles messages", %{socket: socket} do
    target = build(:vehicle)
    expect(VehiclesPubSubMock, :subscribe, 1, fn _ -> target end)

    {:ok, _reply, socket} = subscribe_and_join(socket, "vehicle:id:#{target.id}")

    VehicleChannel.handle_info({:new_vehicles, target}, socket)

    assert_push "stream_data", %{vehicle: ^target}
  end

  test "returns nil when there is no longer data for the vehicle", %{socket: socket} do
    target = build(:vehicle)

    expect(VehiclesPubSubMock, :subscribe, 1, fn _ -> target end)

    {:ok, _reply, socket} = subscribe_and_join(socket, "vehicle:id:#{target.id}")

    VehicleChannel.handle_info({:new_vehicles, nil}, socket)

    assert_push "stream_data", %{vehicle: nil}
  end
end

defmodule MobileAppBackendWeb.VehiclesForRouteChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers

  alias MobileAppBackendWeb.VehiclesForRouteChannel

  setup do
    reassign_env(:mobile_app_backend, MobileAppBackend.Vehicles.PubSub, VehiclesPubSubMock)

    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})
    %{socket: socket}
  end

  test "joins ok", %{socket: socket} do
    route_id = "123"
    direction_id = 0
    vehicle = build(:vehicle, route_id: route_id, direction_id: direction_id)

    expect(VehiclesPubSubMock, :subscribe_for_routes, 1, fn ["123"], 0 ->
      [vehicle]
    end)

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "vehicles:route", %{
        "route_id" => route_id,
        "direction_id" => direction_id
      })

    assert reply == to_full_map([vehicle])
  end

  test "handles new vehicles", %{socket: socket} do
    route_id = "123"
    direction_id = 0
    vehicle = build(:vehicle, route_id: route_id, direction_id: direction_id)
    vehicle2 = build(:vehicle, route_id: route_id, direction_id: direction_id)

    expect(VehiclesPubSubMock, :subscribe_for_routes, 1, fn ["123"], 0 -> [] end)

    {:ok, _reply, socket} =
      subscribe_and_join(socket, "vehicles:routes:123:0")

    VehiclesForRouteChannel.handle_info(
      {:new_vehicles, [vehicle, vehicle2]},
      socket
    )

    assert_push "stream_data", data_map
    assert to_full_map([vehicle, vehicle2]) == data_map
  end

  test "joins multi route ok", %{socket: socket} do
    route_ids = ["123", "456", "789"]
    direction_id = 1
    vehicle1 = build(:vehicle, route_id: Enum.at(route_ids, 0), direction_id: direction_id)
    vehicle2 = build(:vehicle, route_id: Enum.at(route_ids, 1), direction_id: direction_id)
    vehicle3 = build(:vehicle, route_id: Enum.at(route_ids, 2), direction_id: direction_id)

    expect(VehiclesPubSubMock, :subscribe_for_routes, 1, fn ["123", "456", "789"], 1 ->
      [vehicle1, vehicle2, vehicle3]
    end)

    {:ok, reply, _socket} =
      subscribe_and_join(
        socket,
        "vehicles:routes:#{Enum.join(route_ids, ",")}:#{direction_id}",
        %{}
      )

    assert reply == to_full_map([vehicle1, vehicle2, vehicle3])
  end
end

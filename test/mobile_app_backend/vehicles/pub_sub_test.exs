defmodule MobileAppBackend.Vehicles.PubSubTests do
  use ExUnit.Case

  alias MBTAV3API.{Store, Stream}
  alias MobileAppBackend.Vehicles.PubSub
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  setup do
    verify_on_exit!()
    reassign_env(:mobile_app_backend, Store.Vehicles, VehiclesStoreMock)
    :ok
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  describe "init/1" do
    test "subscribes to vehicle events" do
      expect(VehiclesStoreMock, :fetch, fn _ ->
        []
      end)

      PubSub.init(create_table_fn: fn -> :no_op end)

      Stream.PubSub.broadcast!("vehicles:to_store", :reset_event)
      assert_receive :reset_event
    end
  end

  describe "subscribe_for_routes/1" do
    test "returns initial data for the given routes" do
      vehicle_1 = build(:vehicle, id: "v_1")
      vehicle_2 = build(:vehicle, id: "v_2")

      expect(VehiclesStoreMock, :fetch, fn [
                                             [route_id: "123", direction_id: 1],
                                             [route_id: "456", direction_id: 1]
                                           ] ->
        [vehicle_1, vehicle_2]
      end)

      assert [vehicle_1, vehicle_2] == PubSub.subscribe_for_routes(["123", "456"], 1)
    end
  end

  describe "handle_info" do
    setup do
      _dispatched_table = :ets.new(:test_last_dispatched, [:set, :named_table])
      {:ok, %{last_dispatched_table_name: :test_last_dispatched}}
    end

    test "broadcasts on :reset_event" do
      PubSub.handle_info(:reset_event, %{last_dispatched_table_name: :test_last_dispatched})
      assert_receive :broadcast
    end

    test ":broadcast sends message to subscribed pid", state do
      vehicle_1 = build(:vehicle, id: "v_1")
      vehicle_2 = build(:vehicle, id: "v_2")

      VehiclesStoreMock
      # Subscribe
      |> expect(:fetch, fn _ -> [vehicle_1] end)
      # 1st and 2nd broadcast
      |> expect(:fetch, 2, fn _ -> [vehicle_2] end)
      # 3rd broadcast
      |> expect(:fetch, fn _ -> [vehicle_1] end)

      PubSub.subscribe_for_routes(["123"], 1)

      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_vehicles, [^vehicle_2]}

      # Doesn't re-send the same vehicle that have already been seen
      PubSub.handle_info(:broadcast, state)

      refute_receive _

      # Sends new vehicles
      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_vehicles, [^vehicle_1]}
    end
  end
end

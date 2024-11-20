defmodule MobileAppBackend.Alerts.PubSubTests do
  use ExUnit.Case

  alias MBTAV3API.JsonApi.Object
  alias MBTAV3API.{Store, Stream}
  alias MobileAppBackend.Alerts.PubSub
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  setup do
    verify_on_exit!()
    reassign_env(:mobile_app_backend, Store.Alerts, AlertsStoreMock)
    :ok
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  describe "init/1" do
    test "subscribes to alert events" do
      expect(AlertsStoreMock, :fetch, fn _ ->
        []
      end)

      PubSub.init(create_table_fn: fn -> :no_op end)

      Stream.PubSub.broadcast!("alerts:to_store", :reset_event)
      assert_receive :reset_event
    end
  end

  describe "subscribe/1" do
    test "returns initial data" do
      alert_1 = build(:alert, id: "a_1")

      expect(AlertsStoreMock, :fetch, fn [] ->
        [alert_1]
      end)

      assert Object.to_full_map([alert_1]) == PubSub.subscribe()
    end

    test "returns empty list when no alerts" do
      expect(AlertsStoreMock, :fetch, fn [] ->
        []
      end)

      assert Object.to_full_map([]) == PubSub.subscribe()
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
      alert_1 = build(:alert, id: "a_1")
      alert_2 = build(:alert, id: "a_2")

      AlertsStoreMock
      # Subscribe
      |> expect(:fetch, fn _ -> [alert_1] end)
      # 1st and 2nd broadcast
      |> expect(:fetch, 2, fn _ -> [alert_2] end)
      # 3rd broadcast
      |> expect(:fetch, fn _ -> [alert_1] end)

      PubSub.subscribe()

      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert Object.to_full_map([alert_2]) == new_alerts

      # Doesn't re-send the same alerts that have already been seen
      PubSub.handle_info(:broadcast, state)

      refute_receive _

      # Sends new alerts
      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert Object.to_full_map([alert_1]) == new_alerts
    end
  end
end

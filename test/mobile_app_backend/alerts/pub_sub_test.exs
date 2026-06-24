defmodule MobileAppBackend.Alerts.PubSubTests do
  use ExUnit.Case

  alias MBTAV3API.Alert
  alias MBTAV3API.Store
  alias MBTAV3API.Stream
  alias MobileAppBackend.Alerts.PubSub
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  import MobileAppBackend.Factory

  setup do
    reassign_env(:mobile_app_backend, :alerts_broadcast_interval_ms, 10_000)

    verify_on_exit!()
    reassign_env(:mobile_app_backend, Store.Alerts, AlertsStoreMock)
    :ok
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  defp to_alert_map(alerts) do
    %{
      alerts:
        alerts
        |> Enum.map(&{&1.id, &1})
        |> Map.new()
    }
  end

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

      assert to_alert_map([alert_1]) == PubSub.subscribe()
    end

    test "returns empty list when no alerts" do
      expect(AlertsStoreMock, :fetch, fn [] ->
        []
      end)

      assert to_alert_map([]) == PubSub.subscribe()
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
      alert_1 =
        build(:alert,
          id: "a_1",
          cause: :single_tracking,
          active_period: [
            %Alert.ActivePeriod{
              start: ~B[2024-02-12 09:44:04],
              end: nil
            }
          ]
        )

      alert_2 = build(:alert, id: "a_2", cause: :rail_defect)

      AlertsStoreMock
      # Subscribe
      |> expect(:fetch, fn _ -> [alert_1] end)
      # 1st and 2nd broadcast
      |> expect(:fetch, 2, fn _ -> [alert_2] end)
      # 3rd broadcast
      |> expect(:fetch, fn _ -> [alert_1] end)

      PubSub.subscribe(legacy_compatibility: false)

      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert to_alert_map([alert_2]) == new_alerts

      # Doesn't re-send the same alerts that have already been seen
      PubSub.handle_info(:broadcast, state)

      refute_receive _

      # Sends new alerts
      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert to_alert_map([alert_1]) == new_alerts
    end

    test ":broadcast filters out upcoming single tracking alerts", state do
      single_tracking_future =
        build(:alert,
          id: "a_1",
          cause: :single_tracking,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(DateTime.now!("America/New_York"), 10, :minute),
              end: nil
            }
          ]
        )

      single_tracking_now =
        build(:alert,
          id: "a_2",
          cause: :single_tracking,
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(DateTime.now!("America/New_York"), -10, :minute),
              end: nil
            }
          ]
        )

      AlertsStoreMock
      # Subscribe & first broadcast
      |> expect(:fetch, fn _ -> [single_tracking_future, single_tracking_now] end)
      |> expect(:fetch, fn _ -> [single_tracking_future] end)

      assert to_alert_map([single_tracking_now]) ==
               PubSub.subscribe(legacy_compatibility: false)

      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert to_alert_map([]) == new_alerts
    end

    test "legacy compatibility converts v2 alert causes", state do
      alert_1 = build(:alert, id: "a_1", cause: :single_tracking)
      alert_2 = build(:alert, id: "a_2", cause: :rail_defect)
      alert_3 = build(:alert, id: "a_3", cause: :shuttle)

      AlertsStoreMock
      # Subscribe
      |> expect(:fetch, fn _ -> [alert_1] end)
      # Broadcast
      |> expect(:fetch, fn _ -> [alert_2, alert_3] end)

      initial_alerts = PubSub.subscribe(legacy_compatibility: true)
      assert to_alert_map([%Alert{alert_1 | cause: :unknown_cause}]) == initial_alerts

      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}
      assert to_alert_map([%Alert{alert_2 | cause: :unknown_cause}, alert_3]) == new_alerts
    end
  end
end

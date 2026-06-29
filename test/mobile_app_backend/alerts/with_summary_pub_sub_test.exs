defmodule MobileAppBackend.Alerts.WithSummaryPubSubTest do
  use ExUnit.Case

  alias MBTAV3API.Alert
  alias MBTAV3API.Store
  alias MobileAppBackend.Alerts
  alias MobileAppBackend.Alerts.AlertWithSummaries
  alias MobileAppBackend.Alerts.WithSummaryPubSub
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  import MobileAppBackend.Factory

  setup do
    reassign_env(:mobile_app_backend, :alerts_broadcast_interval_ms, 10_000)
    reassign_env(:mobile_app_backend, Alerts.PubSub, AlertsPubSubMock)

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    reassign_env(:mobile_app_backend, Store.Alerts, AlertsStoreMock)
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    verify_on_exit!()
    :ok
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  defp to_alert_map(alerts_with_summaries) do
    %{
      alerts_with_summaries:
        alerts_with_summaries
        |> Map.new(&{&1.id, &1})
    }
  end

  describe "init/1" do
    test "subscribes to alert events" do
      AlertsPubSubMock
      |> expect(:subscribe, fn _ -> %{alerts: %{}} end)

      WithSummaryPubSub.init(create_table_fn: fn -> :no_op end)
    end
  end

  describe "subscribe/1" do
    test "returns initial data" do
      alert_1 = build(:alert, id: "a_1")

      ets_table = :ets.new(nil, [:set])
      :ets.insert(ets_table, {:all_summaries, %{{"en", :card} => %{alert_1.id => alert_1}}})

      assert to_alert_map([alert_1]) == WithSummaryPubSub.subscribe(ets_table: ets_table)
    end

    test "returns empty list when no alerts" do
      ets_table = :ets.new(nil, [:set])
      :ets.insert(ets_table, {:all_summaries, %{{"en", :card} => %{}}})

      assert to_alert_map([]) == WithSummaryPubSub.subscribe(ets_table: ets_table)
    end
  end

  describe "handle_info" do
    setup do
      _dispatched_table = :ets.new(:test_last_dispatched, [:set, :named_table])
      {:ok, %{last_dispatched_table_name: :test_last_dispatched}}
    end

    test "broadcasts on :reset_event", state do
      WithSummaryPubSub.handle_info(:reset_event, state)

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
      # 1st and 2nd broadcast
      |> expect(:fetch, 2, fn _ -> [alert_1] end)
      # 3rd broadcast
      |> expect(:fetch, fn _ -> [alert_2] end)

      GlobalDataCacheMock
      |> stub(:default_key, fn -> :default_key end)
      |> stub(:get_data, fn _ ->
        %{route_patterns: %{}}
      end)

      RepositoryMock |> stub(:stops, fn _, _ -> {:ok, %{data: []}} end)

      WithSummaryPubSub.subscribe(ets_table: state.last_dispatched_table_name)

      WithSummaryPubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert to_alert_map([AlertWithSummaries.from_alert(alert_1, [])]) == new_alerts

      # Doesn't re-send the same alerts that have already been seen
      WithSummaryPubSub.handle_info(:broadcast, state)

      refute_receive _

      # Sends new alerts
      WithSummaryPubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert to_alert_map([AlertWithSummaries.from_alert(alert_2, [])]) == new_alerts
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

      GlobalDataCacheMock
      |> stub(:default_key, fn -> :default_key end)
      |> stub(:get_data, fn _ ->
        %{route_patterns: %{}}
      end)

      RepositoryMock |> stub(:stops, fn _, _ -> {:ok, %{data: []}} end)

      WithSummaryPubSub.handle_info(:broadcast, state)

      assert to_alert_map([AlertWithSummaries.from_alert(single_tracking_now, [])]) ==
               WithSummaryPubSub.subscribe(ets_table: state.last_dispatched_table_name)

      WithSummaryPubSub.handle_info(:broadcast, state)

      assert_receive {:new_alerts, new_alerts}

      assert to_alert_map([]) == new_alerts
    end
  end
end

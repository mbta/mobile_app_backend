defmodule MobileAppBackend.Notifications.EngineTest do
  use ExUnit.Case, async: false
  use HttpStub.Case
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Notifications.Engine
  alias MobileAppBackend.NotificationsFactory

  setup :verify_on_exit!

  test "matches Green Line subscription to individual routes" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Green-D"}]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "line-Green",
        stop_id: "place-boyls",
        direction_id: 0,
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    assert [
             {%AlertSummary{
                effect: :suspension,
                location: %AlertSummary.Location.SuccessiveStops{
                  start_stop_name: "Union Square",
                  end_stop_name: "Riverside"
                },
                timeframe: nil
              }, ^alert, _}
           ] =
             Engine.notifications([subscription], [alert], now)
  end

  test "matches parent subscription to child stop" do
    now = DateTime.now!("America/New_York")

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    GlobalDataCacheMock
    |> expect(:default_key, fn -> :default_key end)
    |> expect(:get_data, fn _ ->
      %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: %{},
        route_patterns: %{},
        stops: %{
          "place-boyls" => %MBTAV3API.Stop{
            child_stop_ids: ["70158"]
          }
        },
        trips: %{}
      }
    end)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], stop: "70158"}]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        stop_id: "place-boyls",
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    assert [{_, ^alert, _}] =
             Engine.notifications([subscription], [alert], now)
  end

  test "includes downstream alerts" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
        effect: :station_closure,
        informed_entity: [
          %Alert.InformedEntity{
            activities: [:board, :exit],
            direction_id: 0,
            route: "Orange",
            stop: "70004"
          },
          %Alert.InformedEntity{
            activities: [:board, :exit],
            direction_id: 1,
            route: "Orange",
            stop: "70005"
          }
        ]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Orange",
        stop_id: "place-north",
        direction_id: 0,
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    assert [{_, ^alert, _}] =
             Engine.notifications([subscription], [alert], now)
  end

  test "includes elevator closures if requested" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
        effect: :elevator_closure,
        informed_entity: [
          %Alert.InformedEntity{
            activities: [:using_wheelchair],
            stop: "place-chncl"
          }
        ]
      )

    subscription_including =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Orange",
        stop_id: "place-chncl",
        direction_id: 0,
        include_accessibility: true,
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    assert [{_, ^alert, _}] =
             Engine.notifications([subscription_including], [alert], now)

    subscription_excluding =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Orange",
        stop_id: "place-chncl",
        direction_id: 0,
        include_accessibility: false
      )

    assert [] = Engine.notifications([subscription_excluding], [alert], now)
  end

  test "sends all clear if closed" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        closed_timestamp: DateTime.add(now, -1),
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [{_, ^alert, :all_clear}] =
             Engine.notifications([subscription], [alert], now)
  end

  test "sends notification with timestamp if open and has timestamp" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
        last_push_notification_timestamp: upstream_timestamp
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [{_, ^alert, {:notification, ^upstream_timestamp}}] =
             Engine.notifications([subscription], [alert], now)
  end

  test "sends notification with timestamp if open" do
    now = DateTime.now!("America/New_York")
    start_time = DateTime.add(now, -1)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: start_time, end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
        last_push_notification_timestamp: nil
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [{_, ^alert, {:notification, ^start_time}}] =
             Engine.notifications([subscription], [alert], now)
  end

  test "sends reminder at 24h-1s if open before active" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %Alert.ActivePeriod{start: now |> DateTime.add(24, :hour) |> DateTime.add(-1), end: nil}
        ],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-2) |> DateTime.to_time(),
            end_time: now |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [{_, ^alert, :reminder}] =
             Engine.notifications([subscription], [alert], now)
  end

  test "does not send reminder at 24h+1s if open before active" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %Alert.ActivePeriod{start: now |> DateTime.add(24, :hour) |> DateTime.add(1), end: nil}
        ],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.to_time(),
            end_time: now |> DateTime.add(2) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [] = Engine.notifications([subscription], [alert], now)
  end

  test "sends reminder at 12h-1s if not open before active" do
    now = DateTime.now!("America/New_York")
    now_plus_12h = DateTime.add(now, 12, :hour)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: now_plus_12h |> DateTime.add(-1), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now_plus_12h |> DateTime.add(-2) |> DateTime.to_time(),
            end_time: now_plus_12h |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [{_, ^alert, :reminder}] =
             Engine.notifications([subscription], [alert], now)
  end

  test "does not send reminder at 12h+1s if not open before active" do
    now = DateTime.now!("America/New_York")
    now_plus_12h = DateTime.add(now, 12, :hour)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now_plus_12h, 1), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now_plus_12h |> DateTime.to_time(),
            end_time: now_plus_12h |> DateTime.add(2) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [] = Engine.notifications([subscription], [alert], now)
  end

  test "picks notification over reminder based on windows" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, 1), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], stop: "place-sstat"}],
        last_push_notification_timestamp: upstream_timestamp
      )

    subscription_now =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    subscription_later =
      NotificationsFactory.build(:notification_subscription,
        route_id: "CR-NewBedford",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(2) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [{_, ^alert, {:notification, ^upstream_timestamp}}] =
             Engine.notifications([subscription_now, subscription_later], [alert], now)
  end

  test "keeps identical summary from multiple routes" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, 1), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], stop: "place-sstat"}],
        last_push_notification_timestamp: upstream_timestamp
      )

    subscription1 =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    subscription2 =
      NotificationsFactory.build(:notification_subscription,
        route_id: "CR-NewBedford",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [
             {%AlertSummary{
                effect: :suspension,
                location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
                timeframe: nil
              }, ^alert, {:notification, ^upstream_timestamp}}
           ] =
             Engine.notifications([subscription1, subscription2], [alert], now)
  end

  test "keeps successive stops if subscribed in both directions" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Green-D"}]
      )

    subscription1 =
      NotificationsFactory.build(:notification_subscription,
        route_id: "line-Green",
        stop_id: "place-boyls",
        direction_id: 0,
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    subscription2 =
      NotificationsFactory.build(:notification_subscription,
        route_id: "line-Green",
        stop_id: "place-boyls",
        direction_id: 1,
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    assert [
             {%AlertSummary{
                effect: :suspension,
                location: %AlertSummary.Location.SuccessiveStops{
                  start_stop_name: "Riverside",
                  end_stop_name: "Union Square"
                },
                timeframe: nil
              }, ^alert, _}
           ] =
             Engine.notifications([subscription1, subscription2], [alert], now)
  end

  test "discards location if disagreements" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, 1), end: nil}],
        effect: :suspension,
        informed_entity: [
          %Alert.InformedEntity{activities: [:board], stop: "place-sstat"},
          %Alert.InformedEntity{activities: [:board], stop: "place-brdwy"}
        ],
        last_push_notification_timestamp: upstream_timestamp
      )

    subscription1 =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    subscription2 =
      NotificationsFactory.build(:notification_subscription,
        route_id: "CR-NewBedford",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [
             {%AlertSummary{
                effect: :suspension,
                location: nil,
                timeframe: nil
              }, ^alert, {:notification, ^upstream_timestamp}}
           ] =
             Engine.notifications([subscription1, subscription2], [alert], now)
  end
end

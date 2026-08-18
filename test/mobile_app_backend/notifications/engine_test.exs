defmodule MobileAppBackend.Notifications.EngineTest do
  use MobileAppBackend.DataCase, async: false
  use HttpStub.Case
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.Engine
  alias MobileAppBackend.Notifications.Engine.OutgoingNotification
  alias MobileAppBackend.Notifications.NotificationTitle
  alias MobileAppBackend.NotificationsFactory

  setup :verify_on_exit!

  test "matches Green Line subscription to single branch" do
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
             %OutgoingNotification{
               title: %NotificationTitle.BareLabel{label: "Green Line D"},
               summary: %AlertSummary.Standard{
                 effect: :suspension,
                 location: %AlertSummary.Location.WholeRoute{
                   route_label: "Green Line D",
                   route_type: :light_rail
                 },
                 timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
               },
               subscriptions: [^subscription],
               alert: ^alert
             }
           ] =
             Engine.notifications([subscription], [alert], now)
  end

  test "matches Green Line subscription to multiple branches" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
        effect: :suspension,
        informed_entity: [
          %Alert.InformedEntity{activities: [:board], route: "Green-D"},
          %Alert.InformedEntity{activities: [:board], route: "Green-E"}
        ]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "line-Green",
        stop_id: "place-boyls",
        direction_id: 0,
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    assert [
             %OutgoingNotification{
               title: %NotificationTitle.BareLabel{label: "Green Line"},
               summary: %AlertSummary.Standard{
                 effect: :suspension,
                 location: nil,
                 timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
               },
               subscriptions: [^subscription],
               alert: ^alert
             }
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
        routes: %{"Green-D" => %MBTAV3API.Route{}},
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
        route_id: "Green-D",
        stop_id: "place-boyls",
        windows: [NotificationsFactory.build(:perpetual_window)]
      )

    assert [%OutgoingNotification{subscriptions: [^subscription], alert: ^alert}] =
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

    assert [%OutgoingNotification{subscriptions: [^subscription], alert: ^alert}] =
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

    assert [%OutgoingNotification{subscriptions: [^subscription_including], alert: ^alert}] =
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

  test "does not send all clear if closed without push notification" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        closed_timestamp: DateTime.add(now, -1),
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
        last_push_notification_timestamp: DateTime.add(now, -2)
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

    assert [] = Engine.notifications([subscription], [alert], now)
  end

  test "sends all clear if closed with push notification" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        closed_timestamp: DateTime.add(now, -1),
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
        last_push_notification_timestamp: DateTime.add(now, -1)
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

    assert [
             %OutgoingNotification{
               subscriptions: [^subscription],
               alert: ^alert,
               type: :all_clear
             }
           ] =
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

    assert [
             %OutgoingNotification{
               subscriptions: [^subscription],
               alert: ^alert,
               type: {:notification, ^upstream_timestamp}
             }
           ] =
             Engine.notifications([subscription], [alert], now)
  end

  test "sends update if notified previously" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
        last_push_notification_timestamp: upstream_timestamp
      )

    user = NotificationsFactory.insert(:user)

    subscription =
      NotificationsFactory.build(:notification_subscription,
        user_id: user.id,
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

    Repo.insert!(%DeliveredNotification{
      user_id: user.id,
      alert_id: alert.id,
      upstream_timestamp:
        alert.last_push_notification_timestamp
        |> DateTime.add(-1, :minute)
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.truncate(:second)
    })

    assert [
             %OutgoingNotification{
               subscriptions: [^subscription],
               alert: ^alert,
               type: {:update, ^upstream_timestamp}
             }
           ] =
             Engine.notifications([subscription], [alert], now)
  end

  test "sends notification with timestamp if open" do
    now = DateTime.now!("America/New_York")
    start_time = DateTime.add(now, -1)
    notification_time = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: start_time, end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
        last_push_notification_timestamp: notification_time
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: start_time |> DateTime.to_time(),
            end_time: now |> DateTime.add(1) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [
             %OutgoingNotification{
               subscriptions: [^subscription],
               alert: ^alert,
               type: {:notification, ^notification_time}
             }
           ] =
             Engine.notifications([subscription], [alert], now)
  end

  test "skips notification if timestamp is nil" do
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

    assert [] = Engine.notifications([subscription], [alert], now)
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

    assert [%OutgoingNotification{subscriptions: [^subscription], alert: ^alert, type: :reminder}] =
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

    assert [%OutgoingNotification{subscriptions: [^subscription], alert: ^alert, type: :reminder}] =
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

  test "uses overlap time instead of just active time" do
    friday_noon = ~B[2026-03-20 12:00:00]
    sunday_noon = ~B[2026-03-22 12:00:00]

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: friday_noon, end: nil}],
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
        last_push_notification_timestamp: friday_noon
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Red",
        stop_id: "place-sstat",
        windows: [
          NotificationsFactory.build(:window,
            start_time: ~T[12:00:00],
            end_time: ~T[14:00:00],
            days_of_week: [7]
          )
        ]
      )

    assert [] = Engine.notifications([subscription], [alert], friday_noon)

    assert [%OutgoingNotification{type: :reminder}] =
             Engine.notifications([subscription], [alert], DateTime.add(sunday_noon, -11, :hour))
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

    assert [
             %OutgoingNotification{
               subscriptions: [^subscription_now],
               alert: ^alert,
               type: {:notification, ^upstream_timestamp}
             }
           ] =
             Engine.notifications([subscription_now, subscription_later], [alert], now)
  end

  test "keeps identical summary from multiple routes" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
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
             %OutgoingNotification{
               summary: %AlertSummary.Standard{
                 effect: :suspension,
                 location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
                 timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
               },
               subscriptions: [_, _],
               alert: ^alert,
               type: {:notification, ^upstream_timestamp}
             }
           ] =
             Engine.notifications([subscription1, subscription2], [alert], now)
  end

  test "keeps successive stops if subscribed in both directions" do
    now = DateTime.now!("America/New_York")

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    green_route_ids = ~w(Green-B Green-C Green-D Green-E)

    routes =
      Map.new(green_route_ids, fn id ->
        route = build(:route, id: id, type: :light_rail, line_id: "line-Green")
        {id, route}
      end)

    patterns =
      Enum.flat_map(green_route_ids, fn id ->
        Enum.map(0..1, fn direction_id ->
          build(:route_pattern,
            route_id: id,
            direction_id: direction_id,
            typicality: :typical,
            representative_trip_id: "#{id}-#{direction_id}-trip"
          )
        end)
      end)

    trips =
      Enum.flat_map(green_route_ids, fn id ->
        Enum.map(0..1, fn direction_id ->
          build(:trip,
            id: "#{id}-#{direction_id}-trip",
            stop_ids:
              if direction_id == 0 do
                ["place-river", "place-unsq", "place-boyls"]
              else
                ["place-boyls", "place-unsq", "place-river"]
              end
          )
        end)
      end)

    GlobalDataCacheMock
    |> expect(:default_key, fn -> :default_key end)
    |> expect(:get_data, fn _ ->
      %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: routes,
        route_patterns: Map.new(patterns, &{&1.id, &1}),
        stops: %{
          "place-boyls" => build(:stop, id: "place-boyls", name: "Boylston"),
          "place-river" => build(:stop, id: "place-river", name: "Riverside"),
          "place-unsq" => build(:stop, id: "place-unsq", name: "Union Square")
        },
        trips: Map.new(trips, &{&1.id, &1})
      }
    end)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
        effect: :suspension,
        informed_entity: [
          %Alert.InformedEntity{activities: [:board], stop: "place-boyls", route: "Green-D"},
          %Alert.InformedEntity{activities: [:board], stop: "place-river", route: "Green-D"}
        ]
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
             %OutgoingNotification{
               summary: %AlertSummary.Standard{
                 effect: :suspension,
                 location: %AlertSummary.Location.SuccessiveStops{
                   start_stop_name: "Boylston",
                   end_stop_name: "Riverside"
                 },
                 timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
               },
               subscriptions: [^subscription1, ^subscription2],
               alert: ^alert
             }
           ] =
             Engine.notifications([subscription1, subscription2], [alert], now)
  end

  test "discards location if disagreements" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
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
             %OutgoingNotification{
               summary: %AlertSummary.Standard{
                 effect: :suspension,
                 location: nil,
                 timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
               },
               subscriptions: [^subscription1, ^subscription2],
               alert: ^alert,
               type: {:notification, ^upstream_timestamp}
             }
           ] =
             Engine.notifications([subscription1, subscription2], [alert], now)
  end

  test "returns a single all clear when multiple subscriptions match" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    alert =
      build(:alert,
        active_period: [
          %Alert.ActivePeriod{start: DateTime.add(now, -10), end: DateTime.add(now, -5)}
        ],
        closed_timestamp: upstream_timestamp,
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
            start_time: now |> DateTime.add(-20) |> DateTime.to_time(),
            end_time: now |> DateTime.add(20) |> DateTime.to_time(),
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
            start_time: now |> DateTime.add(-20) |> DateTime.to_time(),
            end_time: now |> DateTime.add(20) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [
             %OutgoingNotification{
               summary: %AlertSummary.AllClear{
                 location: nil
               },
               subscriptions: [^subscription1, ^subscription2],
               alert: ^alert,
               type: :all_clear
             }
           ] =
             Engine.notifications([subscription1, subscription2], [alert], now)
  end

  test "retrieves schedules for specified trips" do
    now = DateTime.now!("America/New_York")
    service_day = Util.DateTime.datetime_to_gtfs(now)
    upstream_timestamp = DateTime.add(now, -2)

    trip = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
    trip_id = trip.id

    alert =
      build(:alert,
        active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
        effect: :suspension,
        informed_entity: [
          %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_id}
        ],
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

    _ = GlobalDataCache.get_data()
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(
      :schedules,
      fn [
           filter: [trip: [^trip_id], date: ^service_day],
           include: [trip: :stops],
           sort: {:stop_sequence, :asc},
           fields: [stop: []]
         ],
         _ ->
        ok_response([build(:schedule, trip_id: trip_id)], [trip])
      end
    )
    |> expect(
      :trips,
      fn [filter: [id: [^trip_id], date: ^service_day], include: [:stops], fields: [stop: []]],
         _ ->
        ok_response([trip], %{})
      end
    )

    assert [
             %OutgoingNotification{
               subscriptions: [^subscription],
               alert: ^alert,
               type: {:notification, ^upstream_timestamp}
             }
           ] =
             Engine.notifications([subscription], [alert], now)
  end

  test "retrieves schedules for future specified trips" do
    now = DateTime.now!("America/New_York")
    upstream_timestamp = DateTime.add(now, -2)

    trip_1 = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
    trip_1_id = trip_1.id
    trip_2 = build(:trip, route_id: "Red", stop_ids: ["place-sstat"])
    trip_2_id = trip_2.id

    today = Util.DateTime.datetime_to_gtfs(now)
    tomorrow = today |> Date.add(1)

    alert =
      build(:alert,
        active_period: [
          %Alert.ActivePeriod{start: DateTime.add(now, -1), end: DateTime.add(now, 3, :day)}
        ],
        effect: :suspension,
        informed_entity: [
          %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_1_id},
          %Alert.InformedEntity{activities: [:board], route: "Red", trip: trip_2_id}
        ],
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

    _ = GlobalDataCache.get_data()
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(
      :schedules,
      fn [
           filter: [trip: [^trip_1_id, ^trip_2_id], date: ^today],
           include: [trip: :stops],
           sort: {:stop_sequence, :asc},
           fields: [stop: []]
         ],
         _ ->
        ok_response([build(:schedule, trip_id: trip_1_id)], [trip_1])
      end
    )
    |> expect(
      :schedules,
      fn [
           filter: [trip: [^trip_2_id], date: ^tomorrow],
           include: [trip: :stops],
           sort: {:stop_sequence, :asc},
           fields: [stop: []]
         ],
         _ ->
        ok_response([build(:schedule, trip_id: trip_2_id)], [trip_2])
      end
    )
    |> expect(
      :trips,
      fn [
           filter: [id: [^trip_1_id, ^trip_2_id], date: ^today],
           include: [:stops],
           fields: [stop: []]
         ],
         _ ->
        ok_response([trip_1, trip_2])
      end
    )

    assert [
             %OutgoingNotification{
               subscriptions: [^subscription],
               alert: ^alert,
               type: {:notification, ^upstream_timestamp}
             }
           ] =
             Engine.notifications([subscription], [alert], now)
  end

  test "Doesn't send notification for trip that doesn't serve subscribed stop (even if the route sometime serves that stop)" do
    now = ~B[2026-07-31 10:00:00]
    service_date = Util.DateTime.datetime_to_gtfs(now)
    hingham = build(:stop, id: "Hingham", name: "Hingham")
    hull = build(:stop, id: "Hull", name: "Hull")
    george = build(:stop, id: "George", name: "George")
    logan = build(:stop, id: "Logan", name: "Logan")
    route = build(:route, id: "Boat-F2H", type: :ferry, long_name: "Hingham/Hull Ferry")

    trip_stops_at_both =
      build(:trip,
        id: "other",
        direction_id: 1,
        headsign: "Logan",
        route_id: route.id,
        stop_ids: [
          hingham.id,
          hull.id,
          george.id,
          logan.id
        ]
      )

    affected_trip_only_george =
      build(:trip,
        id: "affected",
        direction_id: 1,
        headsign: "Logan",
        route_id: route.id,
        stop_ids: [hingham.id, george.id, logan.id]
      )

    trips =
      [trip_stops_at_both, affected_trip_only_george]
      |> Map.new(fn trip -> {trip.id, trip} end)

    patterns =
      Enum.map([trip_stops_at_both, affected_trip_only_george], fn trip ->
        build(:route_pattern,
          id: "RP_#{trip.id}",
          route_id: route.id,
          direction_id: 1,
          representative_trip_id: trip.id
        )
      end)

    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(
      :schedules,
      1,
      fn [
           filter: [trip: [trip_id], date: ^service_date],
           include: [trip: :stops],
           sort: {:stop_sequence, :asc},
           fields: [stop: []]
         ],
         _ ->
        trip = Map.get(trips, trip_id)

        ok_response(
          Enum.map(trip.stop_ids, fn stop_id ->
            build(:schedule,
              trip_id: trip_id,
              route_id: route.id,
              stop_id: stop_id,
              departure_time: ~B[2026-07-31 10:35:00]
            )
          end),
          [trip]
        )
      end
    )
    |> expect(:trips, 4, fn params, _ ->
      case params do
        [filter: [id: trip_id]] ->
          ok_response([Map.get(trips, trip_id)])

        [filter: [id: [trip_id], date: ^service_date], include: [:stops], fields: [stop: []]] ->
          ok_response([Map.get(trips, trip_id)])
      end
    end)

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    GlobalDataCacheMock
    |> expect(:default_key, 2, fn -> :default_key end)
    |> expect(:get_data, 2, fn _ ->
      %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: %{"Boat-F1" => build(:route, type: :ferry, id: "Boat-F1"), route.id => route},
        route_patterns: Map.new(patterns, &{&1.id, &1}),
        stops: %{
          hingham.id => hingham,
          hull.id => hull,
          george.id => george,
          logan.id => logan
        },
        trips: %{
          trip_stops_at_both.id => trip_stops_at_both,
          affected_trip_only_george.id => affected_trip_only_george
        }
      }
    end)

    alert =
      build(:alert,
        active_period: [
          %Alert.ActivePeriod{start: ~B[2026-07-31 10:15:00], end: ~B[2026-07-31 12:00:00]}
        ],
        duration_certainty: :known,
        effect: :dock_closure,
        informed_entity: [
          %Alert.InformedEntity{
            route: route.id,
            stop: george.id,
            trip: affected_trip_only_george.id,
            direction_id: nil,
            activities: [:board, :exit]
          },
          %Alert.InformedEntity{
            route: "Boat-F1",
            stop: george.id,
            trip: affected_trip_only_george.id,
            direction_id: nil,
            activities: [:board, :exit]
          }
        ]
      )

    subscription_hull =
      NotificationsFactory.build(:notification_subscription,
        route_id: route.id,
        stop_id: hull.id,
        direction_id: 1,
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-10, :hour) |> DateTime.to_time(),
            end_time: now |> DateTime.add(10, :hour) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    subscription_hingham =
      NotificationsFactory.build(:notification_subscription,
        route_id: route.id,
        stop_id: hingham.id,
        direction_id: 1,
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-10, :hour) |> DateTime.to_time(),
            end_time: now |> DateTime.add(10, :hour) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [] =
             Engine.notifications([subscription_hull], [alert], now)

    assert [outgoing_notification] =
             Engine.notifications([subscription_hull, subscription_hingham], [alert], now)

    assert %{body: "10:35 AM ferry to Logan will not stop at George today"} =
             OutgoingNotification.localize(outgoing_notification, "en")
  end

  test "Handles a mix of trip-specific and route-level alerts" do
    now = ~B[2026-07-31 10:00:00]
    hingham = build(:stop, id: "Hingham", name: "Hingham")
    hull = build(:stop, id: "Hull", name: "Hull")
    george = build(:stop, id: "George", name: "George")
    route = build(:route, id: "Boat-F2H", type: :ferry, long_name: "Hingham/Hull Ferry")

    affected_trip =
      build(:trip,
        id: "affected",
        direction_id: 1,
        headsign: "Logan",
        route_id: route.id,
        stop_ids: [hingham.id, george.id]
      )

    other_trip =
      build(:trip,
        id: "other",
        direction_id: 1,
        headsign: "George",
        route_id: route.id,
        stop_ids: [
          hingham.id,
          hull.id,
          george.id
        ]
      )

    trips =
      [other_trip, affected_trip]
      |> Map.new(fn trip -> {trip.id, trip} end)

    patterns =
      Enum.map([other_trip, affected_trip], fn trip ->
        build(:route_pattern,
          id: "RP_#{trip.id}",
          route_id: route.id,
          direction_id: 1,
          representative_trip_id: trip.id
        )
      end)

    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(:trips, 1, fn [filter: [id: [trip_id]], include: [:stops], fields: [stop: []]], _ ->
      ok_response([Map.get(trips, trip_id)])
    end)

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    GlobalDataCacheMock
    |> expect(:default_key, 1, fn -> :default_key end)
    |> expect(:get_data, 1, fn _ ->
      %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: %{"Boat-F1" => build(:route, type: :ferry, id: "Boat-F1"), route.id => route},
        route_patterns: Map.new(patterns, &{&1.id, &1}),
        stops: %{
          hingham.id => hingham,
          hull.id => hull,
          george.id => george
        },
        trips: %{
          other_trip.id => other_trip,
          affected_trip.id => affected_trip
        }
      }
    end)

    alert_trip_specific =
      build(:alert,
        active_period: [
          %Alert.ActivePeriod{start: ~B[2026-07-31 10:15:00], end: ~B[2026-07-31 12:00:00]}
        ],
        duration_certainty: :known,
        effect: :dock_closure,
        informed_entity: [
          %Alert.InformedEntity{
            route: route.id,
            stop: george.id,
            trip: affected_trip.id,
            direction_id: nil,
            activities: [:board, :exit]
          },
          %Alert.InformedEntity{
            route: "Boat-F1",
            stop: george.id,
            trip: affected_trip.id,
            direction_id: nil,
            activities: [:board, :exit]
          }
        ]
      )

    alert_route =
      build(:alert,
        active_period: [
          %Alert.ActivePeriod{start: ~B[2026-07-31 10:15:00], end: ~B[2026-07-31 12:00:00]}
        ],
        duration_certainty: :known,
        effect: :delay,
        severity: 7,
        informed_entity: [
          %Alert.InformedEntity{
            route: route.id,
            direction_id: nil,
            activities: [:board, :exit]
          }
        ]
      )

    subscription_hull =
      NotificationsFactory.build(:notification_subscription,
        route_id: route.id,
        stop_id: hull.id,
        direction_id: 1,
        windows: [
          NotificationsFactory.build(:window,
            start_time: now |> DateTime.add(-10, :hour) |> DateTime.to_time(),
            end_time: now |> DateTime.add(10, :hour) |> DateTime.to_time(),
            days_of_week: Range.to_list(0..6)
          )
        ]
      )

    assert [
             %MobileAppBackend.Notifications.Engine.OutgoingNotification{
               summary: %AlertSummary.Standard{effect: :delay}
             }
           ] =
             Engine.notifications([subscription_hull], [alert_trip_specific, alert_route], now)
  end
end

defmodule MobileAppBackend.Notifications.EngineTest do
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.Engine
  alias MobileAppBackend.Notifications.Engine.OutgoingNotification
  alias MobileAppBackend.Notifications.{NotificationTitle, Subscription}
  alias MobileAppBackend.NotificationsFactory

  use MobileAppBackend.DataCase, async: false
  use HttpStub.Case
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils

  setup :verify_on_exit!

  describe "user_notifications/5" do
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
          user_id: 1,
          route_id: "line-Green",
          stop_id: "place-boyls",
          direction_id: 0,
          windows: [NotificationsFactory.build(:perpetual_window)]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      summary = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.WholeRoute{
          route_label: "Green Line D",
          route_type: :light_rail
        },
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert [
               %OutgoingNotification{
                 title: %NotificationTitle.BareLabel{label: "Green Line D"},
                 summary: ^summary,
                 subscriptions: [^subscription],
                 alert: ^alert
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription) => %{alert.id => {summary, summary}}
                 },
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
          route_id: "line-Green",
          stop_id: "place-boyls",
          direction_id: 0,
          windows: [NotificationsFactory.build(:perpetual_window)]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      summary = %AlertSummary.Standard{
        effect: :suspension,
        location: nil,
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert [
               %OutgoingNotification{
                 title: %NotificationTitle.BareLabel{label: "Green Line"},
                 summary: ^summary,
                 subscriptions: [^subscription],
                 alert: ^alert
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription) => %{alert.id => {summary, summary}}
                 },
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
          route_id: "Green-D",
          stop_id: "place-boyls",
          windows: [NotificationsFactory.build(:perpetual_window)]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [%OutgoingNotification{subscriptions: [^subscription], alert: ^alert}] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
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

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription],
                 alert: ^alert,
                 type: {:notification, ^upstream_timestamp}
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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

      user =
        NotificationsFactory.insert(:user,
          notification_subscriptions: [
            %{
              route_id: "Red",
              stop_id: "place-sstat",
              direction_id: 0,
              include_accessibility: false,
              windows: [
                NotificationsFactory.build(:window,
                  start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
                  end_time: now |> DateTime.add(1) |> DateTime.to_time(),
                  days_of_week: Range.to_list(0..6)
                )
              ]
            }
          ]
        )

      %{notification_subscriptions: [subscription]} = user

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
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "sends no update if already received update" do
      now = DateTime.now!("America/New_York")
      upstream_timestamp = DateTime.add(now, -2)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -1), end: nil}],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
          last_push_notification_timestamp: upstream_timestamp
        )

      user =
        NotificationsFactory.insert(:user,
          notification_subscriptions: [
            %{
              route_id: "Red",
              stop_id: "place-sstat",
              direction_id: 0,
              include_accessibility: false,
              windows: [
                NotificationsFactory.build(:window,
                  start_time: now |> DateTime.add(-1) |> DateTime.to_time(),
                  end_time: now |> DateTime.add(1) |> DateTime.to_time(),
                  days_of_week: Range.to_list(0..6)
                )
              ]
            }
          ]
        )

      %{notification_subscriptions: [subscription]} = user

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert.id,
        upstream_timestamp:
          alert.last_push_notification_timestamp
          |> DateTime.add(-1, :minute)
          |> DateTime.shift_zone!("Etc/UTC")
          |> DateTime.truncate(:second)
      })

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert.id,
        upstream_timestamp:
          alert.last_push_notification_timestamp
          |> DateTime.shift_zone!("Etc/UTC")
          |> DateTime.truncate(:second)
      })

      assert [] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
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

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription],
                 alert: ^alert,
                 type: {:notification, ^notification_time}
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "sends reminder at 24h-1s if open before active" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: now |> DateTime.add(24, :hour) |> DateTime.add(-1),
              end: nil
            }
          ],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
        )

      subscription =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
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

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription],
                 alert: ^alert,
                 type: :reminder
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "does not send reminder at 24h+1s if open before active" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{
              start: now |> DateTime.add(24, :hour) |> DateTime.add(1),
              end: nil
            }
          ],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}]
        )

      subscription =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          route_id: "Red",
          windows: [
            NotificationsFactory.build(:window,
              start_time: now |> DateTime.to_time(),
              end_time: now |> DateTime.add(2) |> DateTime.to_time(),
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
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

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription],
                 alert: ^alert,
                 type: :reminder
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
          route_id: "Red",
          windows: [
            NotificationsFactory.build(:window,
              start_time: now_plus_12h |> DateTime.to_time(),
              end_time: now_plus_12h |> DateTime.add(2) |> DateTime.to_time(),
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "sends notification when overnight window is open before midnight" do
      now = ~B[2026-03-20 22:30:00]
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
          user_id: 1,
          route_id: "Red",
          stop_id: "place-sstat",
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[22:00:00],
              end_time: ~T[03:00:00],
              days_of_week: [5]
            )
          ]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription],
                 alert: ^alert,
                 type: {:notification, ^upstream_timestamp}
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "sends notification when overnight window is still open after midnight" do
      now = ~B[2026-03-21 01:30:00]
      upstream_timestamp = DateTime.add(now, -2)

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -3, :hour), end: nil}],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
          last_push_notification_timestamp: upstream_timestamp
        )

      subscription =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          route_id: "Red",
          stop_id: "place-sstat",
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[22:00:00],
              end_time: ~T[03:00:00],
              days_of_week: [5]
            )
          ]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription],
                 alert: ^alert,
                 type: {:notification, ^upstream_timestamp}
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "does not send notification once an overnight window has closed" do
      now = ~B[2026-03-21 04:00:00]

      alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.add(now, -6, :hour), end: nil}],
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
          last_push_notification_timestamp: DateTime.add(now, -6, :hour)
        )

      subscription =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          route_id: "Red",
          stop_id: "place-sstat",
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[22:00:00],
              end_time: ~T[03:00:00],
              days_of_week: [5]
            )
          ]
        )

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
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

      user = NotificationsFactory.build(:user, id: 1, notification_subscriptions: [subscription])

      assert [] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 friday_noon,
                 GlobalDataCache.get_data()
               )

      assert [%OutgoingNotification{type: :reminder}] =
               Engine.user_notifications(
                 user,
                 %{Subscription.key_properties(subscription) => %{alert.id => {"fake", "fake"}}},
                 %{alert.id => alert},
                 DateTime.add(sunday_noon, -11, :hour),
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
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
          user_id: 1,
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

      summary = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      user =
        NotificationsFactory.build(:user,
          id: 1,
          notification_subscriptions: [subscription_now, subscription_later]
        )

      assert [
               %OutgoingNotification{
                 # Sends notification because of subscription_now, but ok to include both here
                 subscriptions: [^subscription_now],
                 alert: ^alert,
                 type: {:notification, ^upstream_timestamp}
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription_now) => %{
                     alert.id => {summary, summary}
                   },
                   Subscription.key_properties(subscription_later) => %{
                     alert.id => {summary, summary}
                   }
                 },
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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
          user_id: 1,
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
          user_id: 1,
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

      user =
        NotificationsFactory.build(:user,
          id: 1,
          notification_subscriptions: [subscription1, subscription2]
        )

      summary = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert [
               %OutgoingNotification{
                 summary: ^summary,
                 subscriptions: [_, _],
                 alert: ^alert,
                 type: {:notification, ^upstream_timestamp}
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription1) => %{alert.id => {summary, summary}},
                   Subscription.key_properties(subscription2) => %{alert.id => {summary, summary}}
                 },
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
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

      summary = %AlertSummary.AllClear{
        location: nil
      }

      user =
        NotificationsFactory.insert(:user,
          id: 1,
          notification_subscriptions: [
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
            ),
            NotificationsFactory.build(:notification_subscription,
              user_id: 1,
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
          ]
        )

      [subscription1, subscription2] = user.notification_subscriptions

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
                 summary: ^summary,
                 subscriptions: [^subscription1, ^subscription2],
                 alert: ^alert,
                 type: :all_clear
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription1) => %{alert.id => {summary, summary}},
                   Subscription.key_properties(subscription2) => %{alert.id => {summary, summary}}
                 },
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "sends all clear if closed with push notification and previously notified" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          closed_timestamp: DateTime.add(now, -1),
          effect: :suspension,
          informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Red"}],
          last_push_notification_timestamp: DateTime.add(now, -1)
        )

      user =
        NotificationsFactory.insert(:user,
          notification_subscriptions: [
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

      subscription = user.notification_subscriptions |> List.first()

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription],
                 alert: ^alert,
                 type: :all_clear
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription) => %{
                     alert.id => {"fake", "fake"}
                   }
                 },
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    @tag :capture_log
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
          user_id: 1,
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
          user_id: 1,
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

      user =
        NotificationsFactory.build(:user,
          id: 1,
          notification_subscriptions: [subscription1, subscription2]
        )

      summary1 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SuccessiveStops{
          start_stop_name: "South Station",
          end_stop_name: "Broadway"
        },
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      summary2 = %AlertSummary.Standard{
        effect: :suspension,
        location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
        timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
      }

      assert [
               %OutgoingNotification{
                 summary: %AlertSummary.Standard{
                   effect: :suspension,
                   location: %AlertSummary.Location.Omit{
                     reason: :combine_unknown
                   },
                   timeframe: %AlertSummary.Timeframe.UntilFurtherNotice{}
                 },
                 subscriptions: [^subscription1, ^subscription2],
                 alert: ^alert,
                 type: {:notification, ^upstream_timestamp}
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription1) => %{
                     alert.id => {summary1, summary1}
                   },
                   Subscription.key_properties(subscription2) => %{
                     alert.id => {summary2, summary2}
                   }
                 },
                 %{alert.id => alert},
                 now,
                 GlobalDataCache.get_data()
               )
    end

    test "matches trip time rather than active period against window for trip-specific alerts" do
      now = ~B[2026-10-02 10:00:00]

      [stop1, stop2] = build_pair(:stop)
      route = build(:route)
      route_pattern = build(:route_pattern, route_id: route.id)

      trip =
        build(:trip,
          id: "trip",
          direction_id: route_pattern.direction_id,
          route_id: route.id,
          route_pattern_id: route_pattern.id,
          stop_ids: [stop1.id, stop2.id]
        )

      trip_id = trip.id

      route_pattern = %{route_pattern | representative_trip_id: trip.id}

      schedule1 =
        build(:schedule,
          trip_id: trip.id,
          route_id: route.id,
          stop_id: stop1.id,
          departure_time: ~B[2026-10-02 10:15:00]
        )

      schedule2 =
        build(:schedule,
          trip_id: trip.id,
          route_id: route.id,
          stop_id: stop2.id,
          departure_time: ~B[2026-10-02 10:45:00]
        )

      subscription1_early =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          id: "subscription1_early",
          route_id: route.id,
          stop_id: stop1.id,
          direction_id: trip.direction_id,
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[09:30:00],
              end_time: ~T[10:00:00],
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      subscription1_matching =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          id: "subscription1_matching",
          route_id: route.id,
          stop_id: stop1.id,
          direction_id: trip.direction_id,
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[10:00:00],
              end_time: ~T[10:30:00],
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      subscription1_late =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          id: "subscription1_late",
          route_id: route.id,
          stop_id: stop1.id,
          direction_id: trip.direction_id,
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[10:30:00],
              end_time: ~T[11:00:00],
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      subscription2_early =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          id: "subscription2_early",
          route_id: route.id,
          stop_id: stop2.id,
          direction_id: trip.direction_id,
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[10:00:00],
              end_time: ~T[10:30:00],
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      subscription2_matching =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          id: "subscription2_matching",
          route_id: route.id,
          stop_id: stop2.id,
          direction_id: trip.direction_id,
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[10:30:00],
              end_time: ~T[11:00:00],
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      subscription2_late =
        NotificationsFactory.build(:notification_subscription,
          user_id: 1,
          id: "subscription2_late",
          route_id: route.id,
          stop_id: stop2.id,
          direction_id: trip.direction_id,
          windows: [
            NotificationsFactory.build(:window,
              start_time: ~T[11:00:00],
              end_time: ~T[11:30:00],
              days_of_week: Range.to_list(0..6)
            )
          ]
        )

      user =
        NotificationsFactory.build(:user,
          id: 1,
          notification_subscriptions: [
            subscription1_early,
            subscription1_matching,
            subscription1_late,
            subscription2_early,
            subscription2_matching,
            subscription2_late
          ]
        )

      alert1 =
        build(:alert,
          id: "alert1",
          active_period: [
            %Alert.ActivePeriod{start: ~B[2026-10-02 10:00:00], end: ~B[2026-10-02 11:00:00]}
          ],
          effect: :station_closure,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              route: route.id,
              stop: stop1.id,
              trip: trip.id
            }
          ],
          last_push_notification_timestamp: now
        )

      alert2 =
        build(:alert,
          id: "alert2",
          active_period: [
            %Alert.ActivePeriod{start: ~B[2026-10-02 10:00:00], end: ~B[2026-10-02 11:00:00]}
          ],
          effect: :station_closure,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board],
              route: route.id,
              stop: stop2.id,
              trip: trip.id
            }
          ],
          last_push_notification_timestamp: now
        )

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.GlobalDataCache.Module,
        GlobalDataCacheMock
      )

      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          lines: %{},
          pattern_ids_by_stop: %{},
          routes: %{route.id => route},
          route_patterns: %{route_pattern.id => route_pattern},
          stops: %{stop1.id => stop1, stop2.id => stop2},
          trips: %{trip.id => trip}
        }
      end)

      RepositoryMock
      |> expect(
        :schedules,
        6,
        fn
          [
            filter: [trip: [^trip_id], date: ~D[2026-10-02]],
            include: [trip: :stops],
            sort: {:stop_sequence, :asc},
            fields: [stop: []]
          ],
          _ ->
            ok_response([schedule1, schedule2], [trip])
        end
      )

      assert [
               %OutgoingNotification{
                 subscriptions: [^subscription1_matching],
                 alert: ^alert1,
                 type: :reminder
               },
               %OutgoingNotification{
                 subscriptions: [^subscription2_matching],
                 alert: ^alert2,
                 type: :reminder
               }
             ] =
               Engine.user_notifications(
                 user,
                 %{
                   Subscription.key_properties(subscription1_early) => %{
                     alert1.id => {"fake1_early", "fake1_early"}
                   },
                   Subscription.key_properties(subscription1_matching) => %{
                     alert1.id => {"fake1_matching", "fake1_matching"}
                   },
                   Subscription.key_properties(subscription1_late) => %{
                     alert1.id => {"fake1_late", "fake1_late"}
                   },
                   Subscription.key_properties(subscription2_early) => %{
                     alert2.id => {"fake2_early", "fake2_early"}
                   },
                   Subscription.key_properties(subscription2_matching) => %{
                     alert2.id => {"fake2_matching", "fake2_matching"}
                   },
                   Subscription.key_properties(subscription2_late) => %{
                     alert2.id => {"fake2_late", "fake2_late"}
                   }
                 },
                 %{alert1.id => alert1, alert2.id => alert2},
                 now,
                 GlobalDataCache.get_data()
               )
    end
  end

  describe "alerts_for_subscription_key/4" do
    test "includes downstream alerts" do
      now = DateTime.now!("America/New_York")

      downstream_alert =
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

      upstream_alert =
        build(:alert,
          active_period: [%Alert.ActivePeriod{start: DateTime.from_unix!(0), end: nil}],
          effect: :station_closure,
          informed_entity: [
            %Alert.InformedEntity{
              activities: [:board, :exit],
              direction_id: 0,
              route: "Orange",
              stop: "place-ogmnl"
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

      assert [^downstream_alert] =
               Engine.alerts_for_subscription_key(
                 Subscription.key_properties(subscription),
                 [upstream_alert, downstream_alert],
                 now,
                 GlobalDataCache.get_data()
               )
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

      assert [^alert] =
               Engine.alerts_for_subscription_key(
                 Subscription.key_properties(subscription_including),
                 [alert],
                 now,
                 GlobalDataCache.get_data()
               )

      subscription_excluding =
        NotificationsFactory.build(:notification_subscription,
          route_id: "Orange",
          stop_id: "place-chncl",
          direction_id: 0,
          include_accessibility: false
        )

      assert [] =
               Engine.alerts_for_subscription_key(
                 Subscription.key_properties(subscription_excluding),
                 [alert],
                 now,
                 GlobalDataCache.get_data()
               )
    end

    # TODO: schedule-based tests for trip-specific alerts
    # TODO: test has_more_alerts summary picking
    test "includes trip-specific alerts" do
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

      subscription_key = %{
        route_id: "Red",
        stop_id: "place-sstat",
        direction_id: 0,
        include_accessibility: false
      }

      global = GlobalDataCache.get_data()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      RepositoryMock
      |> expect(
        :trips,
        fn [filter: [id: [^trip_id], date: ^service_day], include: [:stops], fields: [stop: []]],
           _ ->
          ok_response([trip], %{})
        end
      )

      assert [^alert] =
               Engine.alerts_for_subscription_key(
                 Subscription.key_properties(subscription_key),
                 [alert],
                 now,
                 global
               )
    end

    test "Doesn't filter out route-only alerts when there are also trip-specific alerts in the feed" do
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
      |> expect(:trips, 1, fn [
                                filter: [id: [trip_id], date: ~D[2026-07-31]],
                                include: [:stops],
                                fields: [stop: []]
                              ],
                              _ ->
        ok_response([Map.get(trips, trip_id)])
      end)

      global = %{
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

      subscription_key = %{
        route_id: route.id,
        stop_id: hull.id,
        direction_id: 1,
        include_accessibility: false
      }

      assert [alert_route] ==
               Engine.alerts_for_subscription_key(
                 Subscription.key_properties(subscription_key),
                 [alert_route, alert_trip_specific],
                 now,
                 global
               )
    end
  end

  describe "schedules_for_alert_trips/4" do
    test "retrieves schedules for future specified trips" do
      now = DateTime.now!("America/New_York")
      upstream_timestamp = DateTime.add(now, -2)

      trip_1 =
        build(:trip,
          id: "trip1",
          route_id: "Red",
          route_pattern_id: "Red-3-0",
          stop_ids: ["place-sstat"]
        )

      trip_2 =
        build(:trip,
          id: "trip2",
          direction_id: trip_1.direction_id,
          route_id: "Red",
          route_pattern_id: "Red-3-0",
          stop_ids: ["place-sstat"]
        )

      today = Util.DateTime.datetime_to_gtfs(now)
      tomorrow = today |> Date.add(1)

      alert =
        build(:alert,
          active_period: [
            %Alert.ActivePeriod{start: DateTime.add(now, -10), end: DateTime.add(now, 3, :day)}
          ],
          effect: :suspension,
          informed_entity: [
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: "trip1"},
            %Alert.InformedEntity{activities: [:board], route: "Red", trip: "trip2"}
          ],
          last_push_notification_timestamp: upstream_timestamp
        )

      schedule_1 =
        build(:schedule, id: "sched1", trip_id: "trip1", route_id: "Red", stop_id: "place-sstat")

      schedule_2 =
        build(:schedule, id: "sched2", trip_id: "trip2", route_id: "Red", stop_id: "place-sstat")

      subscription_key = %{
        route_id: "Red",
        stop_id: "place-sstat",
        direction_id: 0,
        include_accessibility: false
      }

      global_data = GlobalDataCache.get_data()
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

      RepositoryMock
      |> expect(
        :schedules,
        fn
          [
            filter: [trip: ["trip1", "trip2"], date: ^today],
            include: [trip: :stops],
            sort: {:stop_sequence, :asc},
            fields: [stop: []]
          ],
          _ ->
            ok_response(
              [
                schedule_1
              ],
              [trip_1]
            )

          [
            filter: [trip: ["trip2"], date: ^tomorrow],
            include: [trip: :stops],
            sort: {:stop_sequence, :asc},
            fields: [stop: []]
          ],
          _ ->
            ok_response(
              [
                schedule_2
              ],
              [trip_2]
            )
        end
      )
      |> expect(
        :schedules,
        fn [
             filter: [trip: ["trip2"], date: ^tomorrow],
             include: [trip: :stops],
             sort: {:stop_sequence, :asc},
             fields: [stop: []]
           ],
           _ ->
          ok_response([schedule_2], [trip_2])
        end
      )

      assert [schedule_1, schedule_2] ==
               Engine.schedules_for_alert_trips(alert, subscription_key, global_data, now)
    end
  end
end

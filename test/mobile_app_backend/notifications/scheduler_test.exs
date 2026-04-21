defmodule MobileAppBackend.Notifications.SchedulerTest do
  use MobileAppBackend.DataCase, async: true
  use Oban.Testing, repo: MobileAppBackend.Repo
  use HttpStub.Case

  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  alias MBTAV3API.Store
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.NotificationsFactory

  test "sends notifications" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour),
            end: DateTime.add(now, 10, :minute)
          }
        ],
        effect: :suspension,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: "66",
            route_type: :bus
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -1, :minute)
      )

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: "66",
      stop_id: "1",
      direction_id: 0,
      windows: [
        NotificationsFactory.build(:window,
          start_time: now |> DateTime.add(-10, :minute) |> DateTime.to_time(),
          end_time: now |> DateTime.add(10, :minute) |> DateTime.to_time(),
          days_of_week: [Date.day_of_week(now)]
        )
      ]
    )

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => %{
          "type" => "mode_label",
          "label" => "66",
          "mode" => "bus"
        },
        "summary" => %{
          "effect" => "suspension",
          "location" => nil,
          "timeframe" => %{
            "type" => "time",
            "time" => hd(alert.active_period).end |> DateTime.to_iso8601()
          }
        },
        "subscriptions" => [%{"route" => "66", "stop" => "1", "direction" => 0}],
        "upstream_timestamp" => alert.last_push_notification_timestamp
      }
    )
  end

  test "does not send duplicate notifications" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -10, :minute),
            end: DateTime.add(now, 10, :minute)
          }
        ],
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: "66",
            route_type: :bus
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -1, :minute)
      )

    user = NotificationsFactory.insert(:user)

    Repo.insert!(%DeliveredNotification{
      user_id: user.id,
      alert_id: alert.id,
      upstream_timestamp:
        alert.last_push_notification_timestamp
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.truncate(:second)
    })

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: "66",
      stop_id: "1",
      direction_id: 0,
      windows: [
        NotificationsFactory.build(:window,
          start_time: now |> DateTime.add(-10, :minute) |> DateTime.to_time(),
          end_time: now |> DateTime.add(10, :minute) |> DateTime.to_time(),
          days_of_week: [Date.day_of_week(now)]
        )
      ]
    )

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    refute_enqueued(worker: Notifications.Deliverer)
  end

  test "sends notifications preminders starting less than a day in the future" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, 22, :hour),
            end: DateTime.add(now, 27, :hour)
          }
        ],
        effect: :suspension,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: "66",
            route_type: :bus
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -1, :minute)
      )

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: "66",
      stop_id: "1",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => %{
          "type" => "mode_label",
          "label" => "66",
          "mode" => "bus"
        },
        "summary" => %{
          "effect" => "suspension",
          "location" => nil,
          "timeframe" => %{"type" => "starting_tomorrow"}
        },
        "subscriptions" => [%{"route" => "66", "stop" => "1", "direction" => 0}],
        "type" => "reminder",
        "upstream_timestamp" => nil
      }
    )
  end

  test "doesn't crash if issue building notifications" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, 22, :hour),
            end: DateTime.add(now, 27, :hour)
          }
        ],
        effect: :suspension,
        informed_entity: [
          "this is bad"
        ],
        last_push_notification_timestamp: DateTime.add(now, -1, :minute)
      )

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: "66",
      stop_id: "1",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])

    {result, log} =
      with_log([level: :error], fn ->
        perform_job(MobileAppBackend.Notifications.Scheduler, %{})
      end)

    assert {:ok, nil} = result
    assert log =~ "failed find_new_notifications"
    assert log =~ "this is bad"
  end

  test "skips notifications over a day in the future" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, 25, :hour),
            end: DateTime.add(now, 27, :hour)
          }
        ],
        effect: :suspension,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: "66",
            route_type: :bus
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -1, :minute)
      )

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: "66",
      stop_id: "1",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    refute_enqueued(worker: Notifications.Deliverer)
  end

  test "sends all clear notifications" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -25, :hour),
            end: DateTime.add(now, -4, :minute)
          }
        ],
        effect: :suspension,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: "66",
            route_type: :bus
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -20, :minute),
        closed_timestamp: DateTime.add(now, -20, :minute)
      )

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: "66",
      stop_id: "1",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    Repo.insert!(%DeliveredNotification{
      user_id: user.id,
      alert_id: alert.id,
      type: :notification,
      upstream_timestamp:
        DateTime.add(now, -3, :hour)
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.truncate(:second)
    })

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => %{
          "type" => "mode_label",
          "label" => "66",
          "mode" => "bus"
        },
        "summary" => %{
          "type" => "all_clear",
          "location" => nil
        },
        "subscriptions" => [%{"route" => "66", "stop" => "1", "direction" => 0}],
        "type" => "all_clear",
        "upstream_timestamp" => nil
      }
    )
  end

  test "skips notifications that have ended without a closed timestamp" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -25, :hour),
            end: DateTime.add(now, -4, :minute)
          }
        ],
        effect: :suspension,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: "66",
            route_type: :bus
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -20, :minute),
        closed_timestamp: nil
      )

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: "66",
      stop_id: "1",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    Repo.insert!(%DeliveredNotification{
      user_id: user.id,
      alert_id: alert.id,
      type: :notification,
      upstream_timestamp:
        DateTime.add(now, -3, :hour)
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.truncate(:second)
    })

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    refute_enqueued(worker: Notifications.Deliverer)
  end
end

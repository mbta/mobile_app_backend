defmodule MobileAppBackend.Notifications.SchedulerTest do
  use MobileAppBackend.DataCase, async: true
  use Oban.Testing, repo: MobileAppBackend.Repo
  use HttpStub.Case

  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.Store
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.GCPToken
  alias MobileAppBackend.NotificationsFactory

  setup :set_mox_from_context
  setup :verify_on_exit!
  setup {Req.Test, :verify_on_exit!}

  test "sends notifications" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour)
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
        "title" => "66 bus",
        "body" => "Service suspended until further notice",
        "deep_link_path" => "/s/1/r/66/d/0",
        "upstream_timestamp" => alert.last_push_notification_timestamp,
        "type" => "notification",
        "analytics_label" => "route=66;effect=suspension;type=notification"
      }
    )
  end

  test "schedules notification in user's locale" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour)
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

    user = NotificationsFactory.insert(:user, locale: "es")

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
    set_log_level(:info)

    {{:ok, _}, log} =
      with_log([level: :info], fn ->
        perform_job(MobileAppBackend.Notifications.Scheduler, %{})
      end)

    assert log =~ "find_new_notifications_for_user status=ok"

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => "66 autobús",
        "body" => "Servicio suspendido hasta nuevo aviso",
        "deep_link_path" => "/s/1/r/66/d/0",
        "upstream_timestamp" => alert.last_push_notification_timestamp,
        "type" => "notification",
        "analytics_label" => "route=66;effect=suspension;type=notification"
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

  test "sends notification for an overnight window that opened before midnight" do
    now = DateTime.now!("America/New_York")
    current_time = DateTime.to_time(now)

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour)
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
          # Already started, and ends before it started, so the window is overnight
          start_time: Time.add(current_time, -5, :minute),
          end_time: Time.add(current_time, -10, :minute),
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
        "upstream_timestamp" => alert.last_push_notification_timestamp,
        "type" => "notification"
      }
    )
  end

  test "sends notification for an overnight window whose day of week is the previous day" do
    now = DateTime.now!("America/New_York")
    current_time = DateTime.to_time(now)
    yesterday = if Date.day_of_week(now) == 1, do: 7, else: Date.day_of_week(now) - 1

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour)
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
          # Starts after it ends, so the window is overnight and still open from yesterday
          start_time: Time.add(current_time, 10, :minute),
          end_time: Time.add(current_time, 5, :minute),
          days_of_week: [yesterday]
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
        "upstream_timestamp" => alert.last_push_notification_timestamp,
        "type" => "notification"
      }
    )
  end

  test "does not send notification once an overnight window has closed" do
    now = DateTime.now!("America/New_York")
    current_time = DateTime.to_time(now)
    yesterday = if Date.day_of_week(now) == 1, do: 7, else: Date.day_of_week(now) - 1

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour)
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
          # Hasn't started today and already ended yesterday
          start_time: Time.add(current_time, 10, :minute),
          end_time: Time.add(current_time, -5, :minute),
          days_of_week: [yesterday]
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
            start: DateTime.add(now, 22, :hour)
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
        "title" => "66 bus",
        "body" => "Service suspended starting tomorrow",
        "deep_link_path" => "/s/1/r/66/d/0",
        "type" => "reminder",
        "upstream_timestamp" => nil,
        "analytics_label" => "route=66;effect=suspension;type=reminder"
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
    assert log =~ "failed step=catch_all status=error"
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

  test "skips notifications for information alerts" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -2, :hour),
            end: DateTime.add(now, 5, :hour)
          }
        ],
        effect: :detour,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: "66",
            route_type: :bus
          }
        ],
        severity: 1,
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

  test "skips notifications for alert with nil timestamp and reminder period" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour)
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
        last_push_notification_timestamp: nil
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
        "title" => "66 bus",
        "body" => "All clear: Normal service has resumed.",
        "deep_link_path" => "/s/1/r/66/d/0",
        "type" => "all_clear",
        "upstream_timestamp" => nil,
        "analytics_label" => "route=66;effect=suspension;type=all_clear"
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

  test "sends trip cancellation with future active period" do
    now = DateTime.now!("America/New_York")
    service_day = Util.DateTime.datetime_to_gtfs(now)

    route =
      build(:route,
        id: "CR-Fitchburg",
        line_id: "line-Fitchburg",
        long_name: "Fitchburg Line",
        type: :commuter_rail
      )

    route_pattern =
      build(:route_pattern,
        id: "CR-Fitchburg-d82ea33a-1",
        direction_id: 1,
        route_id: route.id,
        representative_trip_id: "ERMLTieJob-819597-438"
      )

    trip =
      build(:trip,
        id: "ERMLTieJob-819597-438",
        route_id: "CR-Fitchburg",
        route_pattern_id: route_pattern.id,
        direction_id: 1,
        stop_ids: ["FR-0201-02"]
      )

    trip_id = trip.id

    trip_time = DateTime.add(now, 3, :hour)

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(trip_time, -1, :hour),
            end: DateTime.add(trip_time, 1, :hour)
          }
        ],
        effect: :cancellation,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: route.id,
            route_type: :commuter_rail,
            direction_id: 1,
            trip: trip.id
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -1, :minute)
      )

    parent_stop =
      build(:stop, id: "place-FR-0201", name: "Concord", child_stop_ids: ["FR-0201-02"])

    stop = build(:stop, id: "FR-0201-02", name: "Concord", parent_station_id: parent_stop.id)

    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(:schedules, 2, fn _, _ ->
      ok_response(
        [
          build(:schedule,
            departure_time: trip_time,
            trip_id: trip.id,
            stop_id: stop.id,
            route_id: route.id
          )
        ],
        [trip]
      )
    end)
    |> expect(
      :trips,
      fn [filter: [id: [^trip_id], date: ^service_day], include: [:stops], fields: [stop: []]],
         _ ->
        ok_response([trip], %{})
      end
    )

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    GlobalDataCacheMock
    |> expect(:default_key, fn -> :default_key end)
    |> expect(:get_data, fn _ ->
      %{
        routes: %{route.id => route},
        route_patterns: %{route_pattern.id => route_pattern},
        trips: %{trip.id => trip},
        stops: %{
          parent_stop.id => parent_stop,
          stop.id => stop
        },
        lines: %{
          "line-Fitchburg" => build(:line, id: "line-Fitchburg")
        }
      }
    end)

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: route.id,
      stop_id: parent_stop.id,
      direction_id: 1,
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
        "title" => "Fitchburg Line",
        "body" =>
          "#{Util.DateTime.datetime_to_string(trip_time, :short_time)} train from Concord is cancelled today",
        "deep_link_path" => "/s/#{parent_stop.id}/r/#{route.id}/d/1",
        "type" => "reminder",
        "upstream_timestamp" => nil,
        "analytics_label" => "route=CR-Fitchburg;effect=cancellation;type=reminder"
      }
    )
  end

  test "sends trip cancellation reminder with near future active period" do
    now = DateTime.now!("America/New_York")
    service_day = Util.DateTime.datetime_to_gtfs(now)

    route =
      build(:route,
        id: "CR-Fitchburg",
        line_id: "line-Fitchburg",
        long_name: "Fitchburg Line",
        type: :commuter_rail
      )

    route_pattern =
      build(:route_pattern,
        direction_id: 1,
        route_id: "CR-Fitchburg",
        representative_trip_id: "ERMLTieJob-819597-438"
      )

    trip =
      build(:trip,
        id: "ERMLTieJob-819597-438",
        route_id: "CR-Fitchburg",
        route_pattern_id: route_pattern.id,
        direction_id: 1,
        stop_ids: ["FR-0201-02"]
      )

    trip_id = trip.id

    trip_time = DateTime.add(now, 20, :minute)

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(trip_time, -1, :hour),
            end: DateTime.add(trip_time, 1, :hour)
          }
        ],
        effect: :cancellation,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            activities: [:board, :exit, :ride],
            route: route.id,
            route_type: :commuter_rail,
            direction_id: 1,
            trip: trip.id
          }
        ],
        last_push_notification_timestamp: DateTime.add(now, -1, :minute)
      )

    parent_stop =
      build(:stop, id: "place-FR-0201", name: "Concord", child_stop_ids: ["FR-0201-02"])

    stop = build(:stop, id: "FR-0201-02", name: "Concord", parent_station_id: parent_stop.id)

    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(:schedules, 2, fn _, _ ->
      ok_response(
        [
          build(:schedule,
            departure_time: trip_time,
            trip_id: trip.id,
            stop_id: stop.id,
            route_id: route.id
          )
        ],
        [trip]
      )
    end)
    |> expect(
      :trips,
      fn [filter: [id: [^trip_id], date: ^service_day], include: [:stops], fields: [stop: []]],
         _ ->
        ok_response([trip], %{})
      end
    )

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    GlobalDataCacheMock
    |> expect(:default_key, fn -> :default_key end)
    |> expect(:get_data, fn _ ->
      %{
        routes: %{route.id => route},
        route_patterns: %{route_pattern.id => route_pattern},
        trips: %{trip.id => trip},
        stops: %{
          parent_stop.id => parent_stop,
          stop.id => stop
        },
        lines: %{
          "line-Fitchburg" => build(:line, id: "line-Fitchburg")
        }
      }
    end)

    user = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user.id,
      route_id: route.id,
      stop_id: parent_stop.id,
      direction_id: 1,
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
        "title" => "Fitchburg Line",
        "body" =>
          "#{Util.DateTime.datetime_to_string(trip_time, :short_time)} train from Concord is cancelled today",
        "deep_link_path" => "/s/#{parent_stop.id}/r/#{route.id}/d/1",
        "type" => "reminder",
        "upstream_timestamp" => nil,
        "analytics_label" => "route=CR-Fitchburg;effect=cancellation;type=reminder"
      }
    )
  end

  test "sends updates" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -10, :minute),
            end: nil
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
        last_push_notification_timestamp: now
      )

    user = NotificationsFactory.insert(:user)

    Repo.insert!(%DeliveredNotification{
      user_id: user.id,
      alert_id: alert.id,
      upstream_timestamp:
        alert.last_push_notification_timestamp
        |> DateTime.add(-1, :minute)
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

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => "66 bus",
        "body" => "Update: Service suspended until further notice",
        "deep_link_path" => "/s/1/r/66/d/0",
        "upstream_timestamp" => alert.last_push_notification_timestamp,
        "type" => "update",
        "analytics_label" => "route=66;effect=suspension;type=update"
      }
    )
  end

  test "retries if previous send failed" do
    now = DateTime.now!("America/New_York")

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: DateTime.add(now, -48, :hour)
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

    reassign_persistent_term(GCPToken.default_key(), %GCPToken.StoredToken{
      token: "gcp_token",
      expires: ~U[9999-12-31 23:59:59Z]
    })

    Req.Test.expect(Util.GCP, fn conn ->
      conn |> Plug.Conn.put_status(418) |> Req.Test.json(%{})
    end)

    with_log(fn ->
      MobileAppBackend.Notifications.Deliverer.new(%{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => "66 bus",
        "body" => "Service suspended until further notice",
        "deep_link_path" => "/s/1/r/66/d/0",
        "upstream_timestamp" => alert.last_push_notification_timestamp,
        "type" => "notification",
        "analytics_label" => "route=66;effect=suspension;type=notification"
      })
      |> Oban.insert!()

      Oban.drain_queue(queue: :default)
    end)

    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => "66 bus",
        "body" => "Service suspended until further notice",
        "deep_link_path" => "/s/1/r/66/d/0",
        "upstream_timestamp" => alert.last_push_notification_timestamp,
        "type" => "notification",
        "analytics_label" => "route=66;effect=suspension;type=notification"
      }
    )
  end

  describe "deep_link_path" do
    test "preserves route stop direction" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [
            %MBTAV3API.Alert.ActivePeriod{
              start: DateTime.add(now, -48, :hour)
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
        args: %{"deep_link_path" => "/s/1/r/66/d/0"}
      )
    end

    test "preserves route stop" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [
            %MBTAV3API.Alert.ActivePeriod{
              start: DateTime.add(now, -48, :hour)
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

      NotificationsFactory.insert(:notification_subscription,
        user_id: user.id,
        route_id: "66",
        stop_id: "1",
        direction_id: 1,
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
        args: %{"deep_link_path" => "/s/1/r/66"}
      )
    end

    test "preserves stop" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [
            %MBTAV3API.Alert.ActivePeriod{
              start: DateTime.add(now, -48, :hour)
            }
          ],
          effect: :suspension,
          informed_entity: [
            %MBTAV3API.Alert.InformedEntity{
              activities: [:board, :exit, :ride],
              route: "66",
              route_type: :bus
            },
            %MBTAV3API.Alert.InformedEntity{
              activities: [:board, :exit, :ride],
              route: "68",
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

      NotificationsFactory.insert(:notification_subscription,
        user_id: user.id,
        route_id: "68",
        stop_id: "1",
        direction_id: 1,
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
          "deep_link_path" => "/s/1",
          "analytics_label" => "route=66,68;effect=suspension;type=notification"
        }
      )
    end

    test "falls back to alert with route" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [
            %MBTAV3API.Alert.ActivePeriod{
              start: DateTime.add(now, -48, :hour)
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

      NotificationsFactory.insert(:notification_subscription,
        user_id: user.id,
        route_id: "66",
        stop_id: "2",
        direction_id: 1,
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
        args: %{"deep_link_path" => "/a/#{alert.id}/r/66"}
      )
    end

    test "falls back to alert without route" do
      now = DateTime.now!("America/New_York")

      alert =
        build(:alert,
          active_period: [
            %MBTAV3API.Alert.ActivePeriod{
              start: DateTime.add(now, -48, :hour)
            }
          ],
          effect: :suspension,
          informed_entity: [
            %MBTAV3API.Alert.InformedEntity{
              activities: [:board, :exit, :ride],
              route: "66",
              route_type: :bus
            },
            %MBTAV3API.Alert.InformedEntity{
              activities: [:board, :exit, :ride],
              route: "68",
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

      NotificationsFactory.insert(:notification_subscription,
        user_id: user.id,
        route_id: "68",
        stop_id: "2",
        direction_id: 1,
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
        args: %{"deep_link_path" => "/a/#{alert.id}"}
      )
    end
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
      2,
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
          %MBTAV3API.Alert.ActivePeriod{
            start: ~B[2026-07-31 10:15:00],
            end: ~B[2026-07-31 12:00:00]
          }
        ],
        duration_certainty: :known,
        effect: :dock_closure,
        informed_entity: [
          %MBTAV3API.Alert.InformedEntity{
            route: route.id,
            stop: george.id,
            trip: affected_trip_only_george.id,
            direction_id: nil,
            activities: [:board, :exit]
          },
          %MBTAV3API.Alert.InformedEntity{
            route: "Boat-F1",
            stop: george.id,
            trip: affected_trip_only_george.id,
            direction_id: nil,
            activities: [:board, :exit]
          }
        ]
      )

    subscription_hull = %{
      route_id: route.id,
      stop_id: hull.id,
      direction_id: 1,
      include_accessibility: false,
      windows: [
        NotificationsFactory.build(:window,
          start_time: now |> DateTime.add(-10, :hour) |> DateTime.to_time(),
          end_time: now |> DateTime.add(10, :hour) |> DateTime.to_time(),
          days_of_week: Range.to_list(0..6)
        )
      ]
    }

    subscription_hingham = %{
      route_id: route.id,
      stop_id: hingham.id,
      direction_id: 1,
      include_accessibility: false,
      windows: [
        NotificationsFactory.build(:window,
          start_time: now |> DateTime.add(-10, :hour) |> DateTime.to_time(),
          end_time: now |> DateTime.add(10, :hour) |> DateTime.to_time(),
          days_of_week: Range.to_list(0..6)
        )
      ]
    }

    %{id: user_hull_only_id} =
      NotificationsFactory.insert(:user,
        notification_subscriptions: [subscription_hull]
      )

    %{id: user_hull_hingham_id} =
      NotificationsFactory.insert(:user,
        notification_subscriptions: [subscription_hull, subscription_hingham]
      )

    start_link_supervised!(Store.Alerts)
    Store.Alerts.process_reset([alert], [])
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{"now" => now})

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user_hull_hingham_id,
        "body" => "10:35 AM ferry to Logan will not stop at George today"
      }
    )

    refute_enqueued(
      worker: Notifications.Deliverer,
      args: %{"user_id" => user_hull_only_id}
    )
  end
end

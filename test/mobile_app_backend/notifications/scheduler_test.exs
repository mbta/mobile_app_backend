defmodule MobileAppBackend.Notifications.SchedulerTest do
  use MobileAppBackend.DataCase, async: true
  use Oban.Testing, repo: MobileAppBackend.Repo
  use HttpStub.Case

  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
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
        "upstream_timestamp" => alert.last_push_notification_timestamp
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
    {:ok, _} = perform_job(MobileAppBackend.Notifications.Scheduler, %{})

    assert_enqueued(
      worker: Notifications.Deliverer,
      args: %{
        "user_id" => user.id,
        "alert_id" => alert.id,
        "title" => "66 autobús",
        "body" => "Servicio suspendido hasta nuevo aviso",
        "deep_link_path" => "/s/1/r/66/d/0",
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
        "title" => "66 bus",
        "body" => "All clear: Regular service",
        "deep_link_path" => "/s/1/r/66/d/0",
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

  test "sends trip cancellation with future active period" do
    now = DateTime.now!("America/New_York")

    route =
      build(:route,
        id: "CR-Fitchburg",
        line_id: "line-Fitchburg",
        long_name: "Fitchburg Line",
        type: :commuter_rail
      )

    trip =
      build(:trip,
        id: "ERMLTieJob-819597-438",
        route_id: "CR-Fitchburg",
        direction_id: 1,
        stop_ids: ["FR-0201-02"]
      )

    start_time = DateTime.add(now, 3, :hour)

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: start_time,
            end: DateTime.add(now, 7, :hour)
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

    parent_stop = build(:stop, id: "place-FR-0201", name: "Concord")
    stop = build(:stop, id: "FR-0201-02", name: "Concord", parent_station_id: parent_stop.id)

    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(:schedules, fn _, _ ->
      ok_response(
        [
          build(:schedule,
            trip_id: trip.id,
            stop_id: stop.id,
            route_id: route.id
          )
        ],
        [trip]
      )
    end)

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
        route_patterns: %{
          "CR-Fitchburg-d82ea33a-1" =>
            build(:route_pattern,
              id: "CR-Fitchburg-d82ea33a-1",
              route_id: route.id,
              representative_trip_id: trip.id
            )
        },
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
          "Trip cancelled starting #{Util.datetime_to_string(start_time, :short_time)} today",
        "deep_link_path" => "/s/#{parent_stop.id}/r/#{route.id}/d/1",
        "type" => "reminder",
        "upstream_timestamp" => nil
      }
    )
  end

  test "sends trip cancellation reminder with near future active period" do
    now = DateTime.now!("America/New_York")

    route =
      build(:route,
        id: "CR-Fitchburg",
        line_id: "line-Fitchburg",
        long_name: "Fitchburg Line",
        type: :commuter_rail
      )

    trip =
      build(:trip,
        id: "ERMLTieJob-819597-438",
        route_id: "CR-Fitchburg",
        direction_id: 1,
        stop_ids: ["FR-0201-02"]
      )

    start_time = DateTime.add(now, 20, :minute)

    alert =
      build(:alert,
        active_period: [
          %MBTAV3API.Alert.ActivePeriod{
            start: start_time,
            end: DateTime.add(now, 7, :hour)
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

    parent_stop = build(:stop, id: "place-FR-0201", name: "Concord")
    stop = build(:stop, id: "FR-0201-02", name: "Concord", parent_station_id: parent_stop.id)

    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    RepositoryMock
    |> expect(:schedules, fn _, _ ->
      ok_response(
        [
          build(:schedule,
            trip_id: trip.id,
            stop_id: stop.id,
            route_id: route.id
          )
        ],
        [trip]
      )
    end)

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
        route_patterns: %{
          "CR-Fitchburg-d82ea33a-1" =>
            build(:route_pattern,
              id: "CR-Fitchburg-d82ea33a-1",
              route_id: route.id,
              representative_trip_id: trip.id
            )
        },
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
          "Trip cancelled starting #{Util.datetime_to_string(start_time, :short_time)} today",
        "deep_link_path" => "/s/#{parent_stop.id}/r/#{route.id}/d/1",
        "type" => "reminder",
        "upstream_timestamp" => nil
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
        args: %{"deep_link_path" => "/s/1"}
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
end

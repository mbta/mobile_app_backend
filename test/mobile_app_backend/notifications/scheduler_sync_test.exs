defmodule MobileAppBackend.Notifications.SchedulerSyncTest do
  @moduledoc """
  Scheduler tests that swap global application env (e.g. `GlobalDataCache.Module`, `MBTAV3API.Repository`).
  They must not run concurrently with other tests, so they live here instead of in the async `SchedulerTest`.
  """
  use MobileAppBackend.DataCase, async: false
  use Oban.Testing, repo: MobileAppBackend.Repo
  use HttpStub.Case

  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.Store
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.NotificationsFactory

  setup :set_mox_from_context
  setup :verify_on_exit!
  setup {Req.Test, :verify_on_exit!}

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

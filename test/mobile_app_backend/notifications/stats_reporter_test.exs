defmodule MobileAppBackend.Notifications.StatsReporterTest do
  use MobileAppBackend.DataCase, async: false
  use Oban.Testing, repo: MobileAppBackend.Repo
  import ExUnit.CaptureLog
  import Test.Support.Helpers
  alias MobileAppBackend.Notifications.StatsReporter
  alias MobileAppBackend.NotificationsFactory

  setup do
    set_log_level(:info)
    :ok
  end

  test "reports route and user stats" do
    user_1 = NotificationsFactory.insert(:user)
    user_2 = NotificationsFactory.insert(:user)

    NotificationsFactory.insert(:notification_subscription,
      user_id: user_1.id,
      route_id: "Red",
      stop_id: "place-pktrm",
      direction_id: 1,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    NotificationsFactory.insert(:notification_subscription,
      user_id: user_2.id,
      route_id: "Red",
      stop_id: "place-pktrm",
      direction_id: 1,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    NotificationsFactory.insert(:notification_subscription,
      user_id: user_2.id,
      route_id: "Red",
      stop_id: "place-pktrm",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    NotificationsFactory.insert(:notification_subscription,
      user_id: user_2.id,
      route_id: "66",
      stop_id: "place-nubn",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    NotificationsFactory.insert(:notification_subscription,
      user_id: user_2.id,
      route_id: "line-Green",
      stop_id: "place-pktrm",
      direction_id: 1,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    NotificationsFactory.insert(:notification_subscription,
      user_id: user_2.id,
      route_id: "line-Green",
      stop_id: "place-pktrm",
      direction_id: 0,
      windows: [NotificationsFactory.perpetual_window_factory()]
    )

    log =
      capture_log([level: :info], fn ->
        :ok = perform_job(StatsReporter, %{})
      end)

    assert log =~ "[info] #{StatsReporter} users_by_route route_id=66 count=1\n"
    assert log =~ "[info] #{StatsReporter} users_by_route route_id=Red count=2\n"
    assert log =~ "[info] #{StatsReporter} users_by_route route_id=line-Green count=1\n"
    assert log =~ "[info] #{StatsReporter} subscriptions_per_user user_count=2 avg=3.0 max=5\n"
  end
end

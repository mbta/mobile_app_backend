defmodule MobileAppBackend.Notifications.DeliveredNotificationPrunerTest do
  alias MBTAV3API.Store.Alerts
  use MobileAppBackend.DataCase, async: false
  use Oban.Testing, repo: MobileAppBackend.Repo
  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Test.Support.Helpers
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.DeliveredNotificationPruner
  alias MobileAppBackend.NotificationsFactory

  defp two_weeks_ago, do: DateTime.utc_now(:second) |> DateTime.shift(week: -2)

  setup do
    start_link_supervised!(MBTAV3API.Store.Alerts)
    Alerts.process_upsert(:add, [build(:alert)])
    set_log_level(:info)
    :ok
  end

  test "removes old notifications for closed alerts" do
    user = NotificationsFactory.insert(:user)
    alert = build(:alert)

    dn =
      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert.id,
        upstream_timestamp: DateTime.utc_now(:second),
        inserted_at: two_weeks_ago()
      })

    assert Repo.all(DeliveredNotification) == [dn]

    log =
      capture_log([level: :info], fn ->
        :ok = perform_job(DeliveredNotificationPruner, %{})
      end)

    assert Repo.all(DeliveredNotification) == []
    assert log =~ "[info] #{DeliveredNotificationPruner} pruned=1\n"
  end

  test "does not remove old notifications for open alerts" do
    user = NotificationsFactory.insert(:user)
    alert = build(:alert)

    :ok = Alerts.process_upsert(:add, [alert])

    dn =
      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert.id,
        upstream_timestamp: DateTime.utc_now(:second),
        inserted_at: two_weeks_ago()
      })

    assert Repo.all(DeliveredNotification) == [dn]

    log =
      capture_log([level: :info], fn ->
        :ok = perform_job(DeliveredNotificationPruner, %{})
      end)

    assert Repo.all(DeliveredNotification) == [dn]
    assert log =~ "[info] #{DeliveredNotificationPruner} pruned=0\n"
  end

  test "does not remove recent notifications for closed alerts" do
    user = NotificationsFactory.insert(:user)
    alert = build(:alert)

    dn =
      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert.id,
        upstream_timestamp: DateTime.utc_now(:second),
        inserted_at: DateTime.utc_now(:second) |> DateTime.shift(day: -6)
      })

    assert Repo.all(DeliveredNotification) == [dn]

    log =
      capture_log([level: :info], fn ->
        :ok = perform_job(DeliveredNotificationPruner, %{})
      end)

    assert Repo.all(DeliveredNotification) == [dn]
    assert log =~ "[info] #{DeliveredNotificationPruner} pruned=0\n"
  end

  test "does not remove notifications if alerts feed is empty" do
    Logger.put_process_level(self(), :none)
    user = NotificationsFactory.insert(:user)
    alert = build(:alert)

    dn =
      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert.id,
        upstream_timestamp: DateTime.utc_now(:second),
        inserted_at: two_weeks_ago()
      })

    assert Repo.all(DeliveredNotification) == [dn]

    Alerts.process_reset([], [])

    assert {:snooze, 60} = perform_job(DeliveredNotificationPruner, %{})

    assert Repo.all(DeliveredNotification) == [dn]
  end
end

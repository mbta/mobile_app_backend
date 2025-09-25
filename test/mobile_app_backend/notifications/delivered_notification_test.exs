defmodule MobileAppBackend.Notifications.DeliveredNotificationTest do
  use MobileAppBackend.DataCase
  import MobileAppBackend.NotificationsFactory
  alias MobileAppBackend.Notifications.DeliveredNotification

  test "can insert delivered notification for user" do
    %{id: user_id} = insert(:user)

    Repo.insert!(%DeliveredNotification{
      user_id: user_id,
      alert_id: "3",
      upstream_timestamp: ~U[2025-09-25 00:00:00Z]
    })
  end

  describe "already_sent?/3" do
    test "true if an exact match exists" do
      user = insert(:user)
      alert_id = "3"
      upstream_timestamp = ~U[2025-09-25 13:06:00Z]

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        upstream_timestamp: upstream_timestamp
      })

      assert DeliveredNotification.already_sent?(user.id, alert_id, upstream_timestamp)
    end

    test "false if a near match exists" do
      user = insert(:user)
      other_user = insert(:user)
      alert_id = "3"
      other_alert_id = "4"
      upstream_timestamp = ~U[2025-09-25 13:08:00Z]
      other_upstream_timestamp = ~U[2025-09-25 13:08:01Z]

      Repo.insert!(%DeliveredNotification{
        user_id: other_user.id,
        alert_id: alert_id,
        upstream_timestamp: upstream_timestamp
      })

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: other_alert_id,
        upstream_timestamp: upstream_timestamp
      })

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        upstream_timestamp: other_upstream_timestamp
      })

      refute DeliveredNotification.already_sent?(user.id, alert_id, upstream_timestamp)
    end
  end
end

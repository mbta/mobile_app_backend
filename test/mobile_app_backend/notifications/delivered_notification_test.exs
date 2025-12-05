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

  describe "can_send?/3" do
    test "reminder if not reminded" do
      user = insert(:user)
      alert_id = "3"

      assert DeliveredNotification.can_send?(user.id, alert_id, :reminder)
    end

    test "no reminder if already reminded" do
      user = insert(:user)
      alert_id = "3"

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        type: :reminder
      })

      refute DeliveredNotification.can_send?(user.id, alert_id, :reminder)
    end

    test "no reminder if already notified" do
      user = insert(:user)
      alert_id = "3"

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        upstream_timestamp: ~U[2025-12-04 13:06:00Z],
        type: :notification
      })

      refute DeliveredNotification.can_send?(user.id, alert_id, :reminder)
    end

    test "notification if not notified" do
      user = insert(:user)
      alert_id = "3"

      assert DeliveredNotification.can_send?(
               user.id,
               alert_id,
               {:notification, ~U[2025-12-04 13:09:00Z]}
             )
    end

    test "no notification if already notified with same upstream timestamp" do
      user = insert(:user)
      alert_id = "3"
      upstream_timestamp = ~U[2025-12-04 13:10:00Z]

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        upstream_timestamp: upstream_timestamp,
        type: :notification
      })

      refute DeliveredNotification.can_send?(
               user.id,
               alert_id,
               {:notification, upstream_timestamp}
             )
    end

    test "notification if already notified with different upstream timestamp" do
      user = insert(:user)
      alert_id = "3"

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        upstream_timestamp: ~U[2025-12-04 13:10:00Z],
        type: :notification
      })

      assert DeliveredNotification.can_send?(
               user.id,
               alert_id,
               {:notification, ~U[2025-12-04 13:11:00Z]}
             )
    end

    test "no all clear if not notified" do
      user = insert(:user)
      alert_id = "3"

      refute DeliveredNotification.can_send?(user.id, alert_id, :all_clear)
    end

    test "all clear if notified and not all clear" do
      user = insert(:user)
      alert_id = "3"

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        upstream_timestamp: ~U[2025-12-04 13:11:00Z],
        type: :notification
      })

      assert DeliveredNotification.can_send?(user.id, alert_id, :all_clear)
    end

    test "no all clear if already all clear" do
      user = insert(:user)
      alert_id = "3"

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        upstream_timestamp: ~U[2025-12-04 13:11:00Z],
        type: :notification
      })

      Repo.insert!(%DeliveredNotification{
        user_id: user.id,
        alert_id: alert_id,
        type: :all_clear
      })

      refute DeliveredNotification.can_send?(user.id, alert_id, :all_clear)
    end
  end
end

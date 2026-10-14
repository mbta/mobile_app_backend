defmodule MobileAppBackend.Notifications.DeliveredNotificationTest do
  use MobileAppBackend.DataCase
  import MobileAppBackend.NotificationsFactory
  alias MobileAppBackend.Factory
  alias MobileAppBackend.Notifications.DeliveredNotification

  test "can insert delivered notification for user" do
    %{id: user_id} = insert(:user)

    Repo.insert!(%DeliveredNotification{
      user_id: user_id,
      alert_id: "3",
      upstream_timestamp: ~U[2025-09-25 00:00:00Z]
    })
  end

  describe "latest_delivered_per_user/1" do
    test "returns only the latest for alerts included in list" do
      %{id: user_1} = insert(:user)
      %{id: user_2} = insert(:user)
      %{id: user_3} = insert(:user)

      first_timestamp = ~U[2025-09-25 00:00:00Z]
      last_timestamp = ~U[2025-09-26 00:00:00Z]

      Repo.insert!(%DeliveredNotification{
        user_id: user_1,
        alert_id: "1",
        inserted_at: first_timestamp
      })

      match_user_1_alert_1 =
        Repo.insert!(%DeliveredNotification{
          user_id: user_1,
          alert_id: "1",
          inserted_at: last_timestamp
        })

      match_user_1_alert_2 =
        Repo.insert!(%DeliveredNotification{
          user_id: user_1,
          alert_id: "2",
          inserted_at: last_timestamp
        })

      Repo.insert!(%DeliveredNotification{
        user_id: user_1,
        alert_id: "other",
        inserted_at: last_timestamp
      })

      match_user_2_alert_1 =
        Repo.insert!(%DeliveredNotification{
          user_id: user_2,
          alert_id: "1",
          inserted_at: last_timestamp
        })

      Repo.insert!(%DeliveredNotification{
        user_id: user_3,
        alert_id: "other",
        inserted_at: last_timestamp
      })

      assert %{
               user_1 => %{"1" => match_user_1_alert_1, "2" => match_user_1_alert_2},
               user_2 => %{"1" => match_user_2_alert_1}
             } == DeliveredNotification.latest_delivered_per_user(["1", "2"])
    end
  end

  describe "can_send?/3" do
    test "reminder if not reminded" do
      alert = Factory.build(:alert)

      assert DeliveredNotification.can_send?(alert, nil, :reminder)
    end

    test "no reminder if already reminded" do
      alert = Factory.build(:alert)

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        type: :reminder
      }

      refute DeliveredNotification.can_send?(alert, delivered, :reminder)
    end

    test "no reminder if already notified" do
      alert = Factory.build(:alert)

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: ~U[2025-12-04 13:06:00Z],
        type: :notification
      }

      refute DeliveredNotification.can_send?(alert, delivered, :reminder)
    end

    test "notification if not notified" do
      alert = Factory.build(:alert)

      assert DeliveredNotification.can_send?(
               alert,
               nil,
               {:notification, ~U[2025-12-04 13:09:00Z]}
             )
    end

    test "no notification if already notified with same upstream timestamp" do
      alert = Factory.build(:alert)
      upstream_timestamp = ~U[2025-12-04 13:10:00Z]

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: upstream_timestamp,
        type: :notification
      }

      refute DeliveredNotification.can_send?(
               alert,
               delivered,
               {:notification, upstream_timestamp}
             )
    end

    test "no notification if already notified with different upstream timestamp" do
      alert = Factory.build(:alert)

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: ~U[2025-12-04 13:10:00Z],
        type: :notification
      }

      refute DeliveredNotification.can_send?(
               alert,
               delivered,
               {:notification, ~U[2025-12-04 13:11:00Z]}
             )
    end

    test "no update if already notified with same upstream timestamp" do
      alert = Factory.build(:alert)
      upstream_timestamp = ~U[2025-12-04 13:10:00Z]

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: upstream_timestamp,
        type: :notification
      }

      refute DeliveredNotification.can_send?(
               alert,
               delivered,
               {:update, upstream_timestamp}
             )
    end

    test "no update if delivered upstream_timestamp is nil and matches" do
      alert = Factory.build(:alert)
      upstream_timestamp = nil

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: upstream_timestamp,
        type: :notification
      }

      refute DeliveredNotification.can_send?(
               alert,
               delivered,
               {:update, upstream_timestamp}
             )
    end

    test "update if delivered upstream_timestamp is nil and update for real time" do
      alert = Factory.build(:alert)

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: nil,
        type: :notification
      }

      assert DeliveredNotification.can_send?(
               alert,
               delivered,
               {:update, ~U[2025-12-04 13:10:00Z]}
             )
    end

    test "update if already notified with different upstream timestamp" do
      alert = Factory.build(:alert)

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: ~U[2025-12-04 13:10:00Z],
        type: :notification
      }

      assert DeliveredNotification.can_send?(
               alert,
               delivered,
               {:update, ~U[2025-12-04 13:11:00Z]}
             )
    end

    test "no all clear if not notified" do
      alert = Factory.build(:alert)

      refute DeliveredNotification.can_send?(alert, nil, :all_clear)
    end

    test "all clear if notified and not all clear" do
      alert = Factory.build(:alert)

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: ~U[2025-12-04 13:11:00Z],
        type: :notification
      }

      assert DeliveredNotification.can_send?(
               alert,
               delivered,
               :all_clear
             )
    end

    test "all clear if reminded and not all clear" do
      alert = Factory.build(:alert)

      delivered = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        upstream_timestamp: ~U[2025-12-04 13:11:00Z],
        type: :reminder
      }

      assert DeliveredNotification.can_send?(
               alert,
               delivered,
               :all_clear
             )
    end

    test "no all clear if already all clear" do
      alert = Factory.build(:alert)

      delivered_all_clear = %DeliveredNotification{
        user_id: "1",
        alert_id: alert.id,
        type: :all_clear
      }

      refute DeliveredNotification.can_send?(alert, delivered_all_clear, :all_clear)
    end
  end
end

defmodule MobileAppBackend.Notifications.WindowTest do
  use MobileAppBackend.DataCase
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.User

  test "can insert windows for subscription" do
    %{id: user_id} =
      MobileAppBackend.Repo.insert!(%User{
        fcm_token: "fake",
        fcm_last_verified: ~U[2025-09-10 00:00:00Z]
      })

    %{id: subscription_id} =
      MobileAppBackend.Repo.insert!(%Subscription{
        user_id: user_id,
        route_id: "Red",
        stop_id: "place-davis",
        direction_id: 0,
        include_accessibility: true
      })

    MobileAppBackend.Repo.insert!(%Window{
      subscription_id: subscription_id,
      start_time: ~T[08:00:00],
      end_time: ~T[09:00:00],
      days_of_week: [0, 1, 2]
    })

    MobileAppBackend.Repo.insert!(%Window{
      subscription_id: subscription_id,
      start_time: ~T[05:00:00],
      end_time: ~T[06:00:00],
      days_of_week: [3, 4, 5]
    })
  end
end

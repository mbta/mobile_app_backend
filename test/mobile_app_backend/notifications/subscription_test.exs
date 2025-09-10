defmodule MobileAppBackend.Notifications.SubscriptionTest do
  use MobileAppBackend.DataCase
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.User

  test "can insert subscription for user" do
    %{id: user_id} =
      MobileAppBackend.Repo.insert!(%User{
        fcm_token: "fake",
        fcm_last_verified: ~U[2025-09-10 00:00:00Z]
      })

    MobileAppBackend.Repo.insert!(%Subscription{
      user_id: user_id,
      route_id: "Red",
      stop_id: "place-davis",
      direction_id: 0,
      include_accessibility: true
    })
  end
end

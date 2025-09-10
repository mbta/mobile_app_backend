defmodule MobileAppBackend.UserTest do
  use MobileAppBackend.DataCase
  alias MobileAppBackend.User

  test "can insert & read from database" do
    MobileAppBackend.Repo.insert!(%User{
      fcm_token: "fake_token",
      fcm_last_verified: ~U[2025-09-10 00:00:00Z]
    })
  end
end

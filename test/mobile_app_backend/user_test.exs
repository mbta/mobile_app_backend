defmodule MobileAppBackend.UserTest do
  use MobileAppBackend.DataCase
  alias MobileAppBackend.User

  test "can insert record for user with new installation id" do
    MobileAppBackend.Repo.insert!(%User{
      fcm_installation_id: "fake_installation_id",
      fcm_last_verified: ~U[2025-09-10 00:00:00Z]
    })
  end

  test "can insert record for user with old token" do
    MobileAppBackend.Repo.insert!(%User{
      fcm_token: "fake_token",
      fcm_last_verified: ~U[2025-09-10 00:00:00Z]
    })
  end

  test "cannot insert record for user with neither token nor installation id" do
    assert_raise Ecto.ConstraintError, fn ->
      MobileAppBackend.Repo.insert!(%User{
        fcm_last_verified: ~U[2025-09-10 00:00:00Z]
      })
    end
  end
end

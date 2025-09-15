defmodule MobileAppBackend.User do
  use MobileAppBackend.Schema

  @moduledoc """
  Represent a mobile app user. Users are not required to log in to a unique account.
  Accordingly, a single device may end up with multiple user records, though old records
  will be pruned and notifications only sent to the newest record for a device.
  """

  typed_schema "users" do
    field(:fcm_token, :string, null: false)
    field(:fcm_last_verified, :utc_datetime, null: false)

    has_many(:notification_subscriptions, MobileAppBackend.Notifications.Subscription,
      on_replace: :delete_if_exists
    )
  end
end

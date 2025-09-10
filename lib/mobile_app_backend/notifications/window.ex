defmodule MobileAppBackend.Notifications.Window do
  use MobileAppBackend.Schema

  typed_schema "notification_subscription_windows" do
    belongs_to(:subscription, MobileAppBackend.Notifications.Subscription)

    field(:start_time, :time, null: false)
    field(:end_time, :time, null: false)
    field(:days_of_week, {:array, :integer}, null: false)

    timestamps(type: :utc_datetime)
  end
end

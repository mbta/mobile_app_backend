defmodule MobileAppBackend.Notifications.Window do
  use MobileAppBackend.Schema

  typed_schema "notification_subscription_windows" do
    belongs_to(:subscription, MobileAppBackend.Notifications.Subscription)

    field(:start_time, :time, null: false)
    field(:end_time, :time, null: false)
    field(:days_of_week, {:array, :integer}, null: false)

    timestamps(type: :utc_datetime)
  end

  def open?(%__MODULE__{} = window, now) do
    now = DateTime.shift_zone!(now, "America/New_York")
    time = DateTime.to_time(now)
    day_of_week = Date.day_of_week(now)

    Time.compare(window.start_time, time) != :gt and Time.compare(time, window.end_time) != :gt and
      day_of_week in window.days_of_week
  end
end

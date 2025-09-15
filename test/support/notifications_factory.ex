defmodule MobileAppBackend.NotificationsFactory do
  use ExMachina.Ecto, repo: MobileAppBackend.Repo

  def notification_subscription_factory do
    %MobileAppBackend.Notifications.Subscription{
      route_id: sequence("route"),
      stop_id: sequence("stop"),
      direction_id: sequence(:direction, [0, 1]),
      include_accessibility: sequence(:include_accessibility, [false, true]),
      windows: [build(:window)]
    }
  end

  def user_factory do
    %MobileAppBackend.User{
      fcm_token: :rand.bytes(64) |> Base.url_encode64(padding: false),
      fcm_last_verified: DateTime.from_unix!(0)
    }
  end

  defp time, do: sequence(:time, &Time.from_seconds_after_midnight(&1 * 60))

  def window_factory do
    days_of_week_count = :rand.normal(3.5, 1) |> round() |> max(1) |> min(7)

    days_of_week =
      Enum.map(1..days_of_week_count, fn _ -> :rand.uniform(7) end) |> Enum.uniq() |> Enum.sort()

    %MobileAppBackend.Notifications.Window{
      start_time: time(),
      end_time: time(),
      days_of_week: days_of_week
    }
  end
end

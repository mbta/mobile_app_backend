defmodule MobileAppBackend.Notifications.Scheduler do
  use Oban.Worker, unique: [period: :infinity, states: :incomplete]
  import Ecto.Query
  alias MBTAV3API.Alert
  alias MBTAV3API.Store.Alerts
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.Deliverer
  alias MobileAppBackend.Notifications.Engine
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  @impl Oban.Worker
  def perform(_) do
    Repo.transact(fn ->
      active_notifications = get_active_notifications()
      open_windows = get_open_windows()

      find_new_recipients(active_notifications, open_windows)
      |> enqueue_delivery()

      {:ok, nil}
    end)
  end

  @typep active_notification :: {Alert.t(), upstream_timestamp :: DateTime.t()}

  @spec get_active_notifications :: [active_notification()]
  defp get_active_notifications do
    alerts = Alerts.fetch([])
    now = DateTime.now!("America/New_York")

    Enum.flat_map(alerts, fn %Alert{} = alert ->
      active? =
        alert.active_period
        |> Enum.any?(fn %Alert.ActivePeriod{} = active_period ->
          DateTime.compare(active_period.start, now) != :gt and
            (is_nil(active_period.end) or DateTime.compare(active_period.end, now) != :lt)
        end)

      if active? and not is_nil(alert.last_push_notification_timestamp) do
        [{alert, alert.last_push_notification_timestamp}]
      else
        []
      end
    end)
  end

  @spec get_open_windows :: %{User.t() => [Subscription.t()]}
  defp get_open_windows do
    current_datetime = DateTime.now!("America/New_York")
    current_day_of_week = Date.day_of_week(current_datetime)
    current_time = DateTime.to_time(current_datetime)

    open_window_users =
      Repo.all(
        from u in User,
          join: s in assoc(u, :notification_subscriptions),
          join: w in assoc(s, :windows),
          where:
            w.start_time <= ^current_time and ^current_time <= w.end_time and
              ^current_day_of_week in w.days_of_week,
          select: %{user: u, subscription: s}
      )

    Enum.group_by(open_window_users, & &1.user, & &1.subscription)
  end

  @spec find_new_recipients([active_notification()], %{User.t() => [Subscription.t()]}) :: [
          {User.t(), active_notification()}
        ]
  defp find_new_recipients(active_notifications, open_windows) do
    Enum.flat_map(active_notifications, fn {%Alert{id: alert_id} = alert, upstream_timestamp} ->
      open_windows
      |> Enum.filter(fn {%User{id: user_id}, subscriptions} ->
        Enum.any?(subscriptions, &Engine.matches?(alert, &1)) and
          not DeliveredNotification.already_sent?(user_id, alert_id, upstream_timestamp)
      end)
      |> Enum.map(fn {user, _} -> {user, {alert, upstream_timestamp}} end)
    end)
  end

  @spec enqueue_delivery([{User.t(), active_notification()}]) :: :ok
  defp enqueue_delivery(recipients) do
    # Unfortunately, Oban.insert_all/3 doesn’t respect uniqueness unless you use Oban Pro.
    Enum.each(recipients, fn {%User{} = recipient, {%Alert{} = alert, upstream_timestamp}} ->
      %{user_id: recipient.id, alert_id: alert.id, upstream_timestamp: upstream_timestamp}
      |> Deliverer.new()
      |> Oban.insert!()
    end)
  end
end

defmodule MobileAppBackend.Notifications.Scheduler do
  use Oban.Worker, unique: [period: :infinity, states: :incomplete], max_attempts: 4
  import Ecto.Query
  require Logger
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
      now = DateTime.now!("America/New_York")
      relevant_alerts = get_relevant_alerts(now)
      open_windows = get_open_windows(now)

      find_new_recipients(relevant_alerts, open_windows, now)
      |> enqueue_delivery()

      {:ok, nil}
    end)
  end

  @spec get_relevant_alerts(DateTime.t()) :: [Alert.t()]
  defp get_relevant_alerts(now) do
    alerts = Alerts.fetch([])

    Enum.filter(alerts, fn %Alert{} = alert -> filter_alert(alert, now) end)
  end

  @spec filter_alert(Alert.t(), DateTime.t()) :: boolean()
  defp filter_alert(%Alert{} = alert, now) do
    # to send anything, the alert must be significant
    significant? = Alert.significance(alert, now) != nil

    # to send a reminder, the alert must be active at some point within the next 24h
    # to send a notification, the alert must be active right now
    active_now_or_soon? =
      alert.active_period
      |> Enum.any?(fn %Alert.ActivePeriod{start: active_start, end: active_end} ->
        start_hours_away = DateTime.diff(now, active_start, :hour)
        ends_in_future? = is_nil(active_end) or DateTime.compare(active_end, now) != :lt

        start_hours_away < 24 and ends_in_future?
      end)

    # to send an all clear, the alert must have an all clear timestamp
    all_clear? = not is_nil(alert.closed_timestamp)

    significant? and (active_now_or_soon? or all_clear?)
  catch
    :exit, error ->
      Logger.error(
        "#{__MODULE__} failed to process alert alert=#{alert.id} error=#{inspect(error)}"
      )

      false
  end

  @spec get_open_windows(DateTime.t()) :: [User.t()]
  defp get_open_windows(now) do
    # to receive a reminder, the window must be open either right now or in twelve hours
    # to receive a notification or all clear, the window must be open right now
    current_datetime = now
    current_day_of_week = Date.day_of_week(current_datetime)
    current_time = DateTime.to_time(current_datetime)

    reminder_target = DateTime.add(current_datetime, 12, :hour)
    reminder_target_day_of_week = Date.day_of_week(reminder_target)
    reminder_target_time = DateTime.to_time(reminder_target)

    {query_us, users_with_open_windows} =
      :timer.tc(
        fn ->
          Repo.all(
            from u in User,
              join: s in assoc(u, :notification_subscriptions),
              join: w in assoc(s, :windows),
              where:
                (w.start_time <= ^current_time and ^current_time <= w.end_time and
                   ^current_day_of_week in w.days_of_week) or
                  (w.start_time <= ^reminder_target_time and ^reminder_target_time <= w.end_time and
                     ^reminder_target_day_of_week in w.days_of_week),
              preload: [notification_subscriptions: {s, windows: w}]
          )
        end,
        :microsecond
      )

    Logger.info("#{__MODULE__} open_windows_query duration=#{query_us}")

    users_with_open_windows
  end

  @spec find_new_recipients([Alert.t()], [User.t()], DateTime.t()) :: [
          {User.t(), Engine.OutgoingNotification.t()}
        ]
  defp find_new_recipients(alerts, users, now) do
    Enum.flat_map(users, &new_notifications(&1, alerts, now))
  end

  defp new_notifications(
         %User{id: user_id, notification_subscriptions: subscriptions} = user,
         alerts,
         now
       ) do
    {engine_us, outgoing_notifications} =
      :timer.tc(&Engine.notifications/3, [subscriptions, alerts, now], :microsecond)

    Logger.info("#{__MODULE__} run_engine duration=#{engine_us}")

    Enum.flat_map(outgoing_notifications, fn outgoing_notification ->
      try do
        if DeliveredNotification.can_send?(
             user_id,
             outgoing_notification.alert.id,
             outgoing_notification.type
           ) do
          [{user, outgoing_notification}]
        else
          []
        end
      catch
        :exit, error ->
          Logger.error(
            "#{__MODULE__} failed to check notification sending for user_id=#{user_id} alert_id=#{outgoing_notification.alert.id} error=#{inspect(error)}"
          )

          []
      end
    end)
  catch
    :exit, error ->
      Logger.error(
        "#{__MODULE__} failed to find new notifications for user_id=#{user_id} error=#{inspect(error)}"
      )

      []
  end

  @spec enqueue_delivery([{User.t(), Engine.OutgoingNotification.t()}]) :: :ok
  defp enqueue_delivery(recipients) do
    # Unfortunately, Oban.insert_all/3 doesn’t respect uniqueness unless you use Oban Pro.
    Enum.each(recipients, &deliver_notification/1)
  end

  defp deliver_notification({%User{} = recipient, %Engine.OutgoingNotification{} = notification}) do
    {type, upstream_timestamp} =
      case notification.type do
        {type, upstream_timestamp} -> {type, upstream_timestamp}
        type when is_atom(type) -> {type, nil}
      end

    subscriptions =
      Enum.map(
        notification.subscriptions,
        fn %Subscription{route_id: route_id, stop_id: stop_id, direction_id: direction_id} ->
          %{route: route_id, stop: stop_id, direction: direction_id}
        end
      )

    %{
      user_id: recipient.id,
      alert_id: notification.alert.id,
      title: notification.title,
      summary: notification.summary,
      subscriptions: subscriptions,
      upstream_timestamp: upstream_timestamp,
      type: type
    }
    |> Deliverer.new()
    |> Oban.insert!()
  catch
    :exit, error ->
      Logger.error(
        "#{__MODULE__} failed to enqueue delivery for user_id=#{recipient.id} alert_id=#{notification.alert.id} error=#{inspect(error)}"
      )

      :ok
  end
end

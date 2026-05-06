defmodule MobileAppBackend.Notifications.Scheduler do
  alias MobileAppBackend.Notifications.Engine.OutgoingNotification
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

  @default_locale Application.compile_env!(:mobile_app_backend, :default_locale_code)

  @impl Oban.Worker
  def perform(_) do
    now = DateTime.now!("America/New_York")
    relevant_alerts = get_relevant_alerts(now)
    open_windows = get_open_windows(now)

    find_new_recipients(relevant_alerts, open_windows, now)
    |> enqueue_delivery()

    {:ok, nil}
  end

  @spec get_relevant_alerts(DateTime.t()) :: [Alert.t()]
  defp get_relevant_alerts(now) do
    alerts = Alerts.fetch([])

    Enum.filter(alerts, fn %Alert{} = alert -> filter_alert(alert, now) end)
  end

  @spec filter_alert(Alert.t(), DateTime.t()) :: boolean()
  defp filter_alert(%Alert{} = alert, now) do
    Alert.significance(alert) != nil && Alert.can_notify?(alert, now)
  rescue
    error ->
      log_exception(
        "process_alert",
        "alert=#{alert.id}",
        Exception.format(:error, error, __STACKTRACE__)
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
          {User.t(), OutgoingNotification.Localized.t()}
        ]
  defp find_new_recipients(alerts, users, now) do
    Enum.flat_map(users, &new_notifications(&1, alerts, now))
  end

  @spec new_notifications(User.t(), [Alert.t()], DateTime.t()) :: [
          {User.t(), OutgoingNotification.Localized.t()}
        ]
  defp new_notifications(
         %User{id: user_id, notification_subscriptions: subscriptions, locale: locale} = user,
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
          localized_notification =
            OutgoingNotification.localize(outgoing_notification, locale || @default_locale)

          [{user, localized_notification}]
        else
          []
        end
      rescue
        error ->
          log_exception(
            "check_notification_sending",
            "user_id=#{user_id} alert_id=#{outgoing_notification.alert.id}",
            Exception.format(:error, error, __STACKTRACE__)
          )

          []
      end
    end)
  rescue
    error ->
      log_exception(
        "find_new_notifications",
        "user_id=#{user_id}",
        Exception.format(:error, error, __STACKTRACE__)
      )

      []
  end

  @spec enqueue_delivery([{User.t(), OutgoingNotification.Localized.t()}]) :: :ok
  defp enqueue_delivery(recipients) do
    # Unfortunately, Oban.insert_all/3 doesn’t respect uniqueness unless you use Oban Pro.
    Enum.each(recipients, &deliver_notification/1)
  end

  defp deliver_notification(
         {%User{} = recipient, %OutgoingNotification.Localized{} = notification}
       ) do
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
      alert_id: notification.alert_id,
      title: notification.title,
      body: notification.body,
      deep_link_path: deep_link_path(notification.alert_id, subscriptions),
      upstream_timestamp: upstream_timestamp,
      type: type
    }
    |> Deliverer.new()
    |> Oban.insert!()
  rescue
    error ->
      log_exception(
        "enqueue_delivery",
        "user_id=#{recipient.id} alert_id=#{notification.alert_id}",
        Exception.format(:error, error, __STACKTRACE__)
      )

      :ok
  end

  @spec deep_link_path(Alert.id(), [
          %{route: MBTAV3API.Route.id(), stop: MBTAV3API.Stop.id(), direction: 0 | 1}
        ]) :: String.t()
  defp deep_link_path(alert_id, subscriptions) do
    stop_piece =
      subscriptions
      |> Enum.uniq_by(& &1.stop)
      |> case do
        [%{stop: stop}] -> "/s/#{stop}"
        _ -> ""
      end

    route_piece =
      subscriptions
      |> Enum.uniq_by(& &1.route)
      |> case do
        [%{route: route}] -> "/r/#{route}"
        _ -> ""
      end

    direction_piece =
      subscriptions
      |> Enum.uniq_by(& &1.direction)
      |> case do
        [%{direction: direction}] -> "/d/#{direction}"
        _ -> ""
      end

    if stop_piece != "" do
      stop_piece <> route_piece <> direction_piece
    else
      "/a/#{alert_id}" <> route_piece <> stop_piece
    end
  end

  defp log_exception(step_name, metadata, error) do
    Logger.error("#{__MODULE__} failed #{step_name} #{metadata} error=#{inspect(error)}")
  end
end

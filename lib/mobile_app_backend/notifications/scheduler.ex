defmodule MobileAppBackend.Notifications.Scheduler do
  alias MobileAppBackend.Notifications.DeliveredNotification
  use Oban.Worker, unique: [period: :infinity, states: :incomplete], max_attempts: 4
  import Ecto.Query
  require Logger

  alias MBTAV3API.{Alert, RoutePattern, Schedule}
  alias MBTAV3API.Store.Alerts
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.Deliverer
  alias MobileAppBackend.Notifications.Engine
  alias MobileAppBackend.Notifications.Engine.OutgoingNotification
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  @default_locale MobileAppBackend.Application.default_locale()

  @impl Oban.Worker
  def perform(%{args: args}) do
    now =
      if Map.has_key?(args, "now") do
        {:ok, now, _offset} = DateTime.from_iso8601(Map.get(args, "now"))
        DateTime.shift_zone!(now, "America/New_York")
      else
        DateTime.now!("America/New_York")
      end

    try do
      relevant_alerts = get_relevant_alerts(now)
      users_with_open_windows = users_with_open_windows(now)
      global = MobileAppBackend.GlobalDataCache.get_data()

      users_with_open_windows
      |> new_notifications(relevant_alerts, now, global)
      |> enqueue_delivery()
    rescue
      error ->
        log_exception(
          "catch_all",
          "status=error",
          Exception.format(:error, error, __STACKTRACE__)
        )
    end

    {:ok, nil}
  end

  @spec get_relevant_alerts(DateTime.t()) :: [Alert.t()]
  defp get_relevant_alerts(now) do
    alerts = Alerts.fetch([])

    Logger.debug(
      "#{__MODULE__} alert_ids=#{inspect(Enum.map(alerts, & &1.id), pretty: false, width: :infinity)}"
    )

    Enum.filter(alerts, fn %Alert{} = alert -> filter_alert(alert, now) end)
  end

  @spec filter_alert(Alert.t(), DateTime.t()) :: boolean()
  defp filter_alert(%Alert{} = alert, now) do
    Alert.should_notify?(alert, now)
  rescue
    error ->
      log_exception(
        "process_alert",
        "alert=#{alert.id}",
        Exception.format(:error, error, __STACKTRACE__)
      )

      false
  end

  @spec users_with_open_windows(DateTime.t()) :: [User.t()]
  defp users_with_open_windows(now) do
    # to receive a reminder, the window must be open either right now or in twelve hours
    # to receive a notification or all clear, the window must be open right now
    reminder_target = DateTime.add(now, 12, :hour)

    window_binding = :window

    {query_us, users_with_open_windows} =
      :timer.tc(
        fn ->
          Repo.all(
            from u in User,
              join: s in assoc(u, :notification_subscriptions),
              join: w in assoc(s, :windows),
              as: ^window_binding,
              where: ^Window.open_dynamic(window_binding, now),
              or_where: ^Window.open_dynamic(window_binding, reminder_target),
              preload: [notification_subscriptions: {s, windows: w}]
          )
        end,
        :microsecond
      )

    Logger.info(
      "#{__MODULE__} open_windows_query duration=#{query_us} user_count=#{length(users_with_open_windows)}"
    )

    users_with_open_windows
  end

  @spec new_notifications([User.t()], [Alert.t()], DateTime.t(), GlobalDataCache.data()) :: [
          {User.t(), OutgoingNotification.Localized.t()}
        ]
  def new_notifications(users, alerts, now, global) do
    alerts_by_id = Map.new(alerts, &{&1.id, &1})

    subscription_keys =
      users
      |> Enum.flat_map(& &1.notification_subscriptions)
      |> Enum.map(&Subscription.key_properties/1)
      |> MapSet.new()

    summaries_by_key =
      Map.new(subscription_keys, fn subscription_key ->
        {subscription_key, summaries_by_subscription_key(subscription_key, alerts, now, global)}
      end)

    last_delivered_by_user_and_alert =
      DeliveredNotification.latest_delivered_per_user(Map.keys(alerts_by_id))

    {notifications_per_user, success_count, error_count} =
      Enum.reduce(users, {[], 0, 0}, fn user, {acc, success_count, error_count} ->
        try do
          outgoing_notifications =
            Engine.user_notifications(
              user,
              Map.get(last_delivered_by_user_and_alert, user.id, %{}),
              summaries_by_key,
              alerts_by_id,
              now,
              global
            )
          Enum.each(outgoing_notifications, fn notification ->
            log_alert_summary_type_issues(notification.alert, notification.summary, user.notification_subscriptions)
          end)
          results = localize_notifications(user, outgoing_notifications)
          {[acc | results], success_count + 1, error_count}
        rescue
          error ->
            log_exception(
              "new_notifications",
              "status=error user_id=#{user.id}",
              Exception.format(:error, error, __STACKTRACE__)
            )

            {acc, success_count, error_count + 1}
        end
      end)

    Logger.info(
      "#{__MODULE__} find_new_notifications_for_user success_count=#{success_count} error_count=#{error_count}"
    )

    List.flatten(notifications_per_user)
  end

  @spec localize_notifications(User.t(), [OutgoingNotification.t()]) :: [
          {User.t(), OutgoingNotification.Localized.t()}
        ]
  def localize_notifications(user, outgoing_notifications) do
    outgoing_notifications
    |> Enum.map(fn outgoing_notification ->
      {user, OutgoingNotification.localize(outgoing_notification, user.locale || @default_locale)}
    end)
  end

  @spec summaries_by_subscription_key(
          Subscription.key_properties(),
          [Alert.t()],
          DateTime.t(),
          GlobalDataCache.data()
        ) ::
          %{Alert.id() => %{default: AlertSummary.t(), multiple_active: AlertSummary.t()}}

  defp summaries_by_subscription_key(subscription_key, alerts, now, global) do
    relevant_alerts = Engine.alerts_for_subscription_key(subscription_key, alerts, now, global)

    patterns =
      RoutePattern.get_relevant_patterns(
        subscription_key.route_id,
        subscription_key.stop_id,
        subscription_key.direction_id,
        global
      )

    summaries_per_alert =
      Map.new(
        relevant_alerts,
        fn alert ->
          schedules = Engine.schedules_for_alert_trips(alert, subscription_key, global, now)

          summary_no_other_active_alerts =
            AlertSummary.summarizing(
              alert,
              %Subscription{
                route_id: subscription_key.route_id,
                stop_id: subscription_key.stop_id,
                direction_id: subscription_key.direction_id,
                include_accessibility: subscription_key.include_accessibility
              },
              patterns,
              now,
              schedules,
              global,
              :notification,
              false
            )

          summary_has_multiple_active_alerts =
            AlertSummary.summarizing(
              alert,
              %Subscription{
                route_id: subscription_key.route_id,
                stop_id: subscription_key.stop_id,
                direction_id: subscription_key.direction_id,
                include_accessibility: subscription_key.include_accessibility
              },
              patterns,
              now,
              schedules,
              global,
              :notification,
              true
            )

          {alert.id,
           %{
             default: summary_no_other_active_alerts,
             multiple_active: summary_has_multiple_active_alerts
           }}
        end
      )

    summaries_per_alert
  end

  @spec log_alert_summary_type_issues(Alert.t(), AlertSummary.t(), [UserNotificationSubscription.t()]) :: :ok
  defp log_alert_summary_type_issues(alert, alert_summary, user_notification_subscriptions) do
    case alert_summary do
      %AlertSummary.Standard{} ->
        if Alert.trip_ids(alert) != [] do
          Logger.warning(
            "Alert #{alert.id} has trips Ids but is summarized as Standard. user_notification_subscriptions: #{inspect(user_notification_subscriptions)}"
          )
        end

      %AlertSummary.TripSpecific{} ->
        if Alert.trip_ids(alert) == [] do
          Logger.warning(
            "Alert #{alert.id} has no trip Ids but is summarized as Trip Specific. user_notification_subscriptions: #{inspect(user_notification_subscriptions)}"
          )
        end

      %AlertSummary.TripShuttle{} ->
        if Alert.trip_ids(alert) == [] do
          Logger.warning(
            "Alert #{alert.id} has no trip Ids but is summarized as Trip Shuttle. user_notification_subscriptions: #{inspect(user_notification_subscriptions)}"
          )
        end

      _ ->
        :ok
    end

    :ok
  end

  @spec enqueue_delivery([{User.t(), OutgoingNotification.Localized.t()}]) :: :ok
  defp enqueue_delivery(user_notifications) do
    user_notifications
    |> Enum.map(&deliverer_job/1)
    # Oban.insert_all doesn't respect uniqueness constraints, but
    # Deliverer does its own checks to prevent sending duplicate notifications
    |> Enum.chunk_every(100)
    |> Enum.each(&Oban.insert_all(&1))

    :ok
  rescue
    error ->
      log_exception(
        "enqueue_delivery",
        "",
        Exception.format(:error, error, __STACKTRACE__)
      )

      :ok
  end

  defp deliverer_job({%User{} = recipient, %OutgoingNotification.Localized{} = notification}) do
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

    Deliverer.new(%{
      user_id: recipient.id,
      alert_id: notification.alert_id,
      title: notification.title,
      body: notification.body,
      deep_link_path: deep_link_path(notification.alert_id, subscriptions),
      upstream_timestamp: upstream_timestamp,
      type: type,
      analytics_label: analytics_label(subscriptions, notification.alert_effect, type),
      metadata: %{subscriptions: subscriptions, locale: notification.locale}
    })
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

  @spec analytics_label(
          [%{route: MBTAV3API.Route.id(), stop: MBTAV3API.Stop.id(), direction: 0 | 1}],
          Alert.effect(),
          atom()
        ) :: String.t()
  defp analytics_label(subscriptions, alert_effect, type) do
    route_ids = subscriptions |> Enum.map(& &1.route) |> Enum.uniq() |> Enum.join(",")
    "route=#{route_ids};effect=#{alert_effect};type=#{type}"
  end

  defp log_exception(step_name, metadata, error) do
    Logger.error("#{__MODULE__} failed step=#{step_name} #{metadata} error=#{inspect(error)}")
  end
end

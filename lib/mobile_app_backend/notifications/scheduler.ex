defmodule MobileAppBackend.Notifications.Scheduler do
  alias MBTAV3API.{Alert, RoutePattern, Schedule}
  alias MBTAV3API.Store.Alerts
  alias MobileAppBackend.Alerts.AlertSummary

  alias MobileAppBackend.Notifications.Engine.OutgoingNotification
  alias MobileAppBackend.Notifications.Deliverer
  alias MobileAppBackend.Notifications.Engine
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  use Oban.Worker, unique: [period: :infinity, states: :incomplete], max_attempts: 4
  import Ecto.Query
  require Logger

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
      open_windows = get_open_windows(now)

      relevant_alerts
      |> notifications_to_send(open_windows, now)
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
    Alert.eligible_for_notification?(alert) && alert.severity >= 3 &&
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

    Logger.info("#{__MODULE__} open_windows_query duration=#{query_us}")

    users_with_open_windows
  end

  @spec notifications_to_send([Alert.t()], [User.t()], DateTime.t()) :: [
          {User.t(), OutgoingNotification.Localized.t()}
        ]
  defp notifications_to_send(alerts, users, now) do
    global = MobileAppBackend.GlobalDataCache.get_data()

    new_notifications(users, alerts, now, global)
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

    Enum.flat_map(users, fn user ->
      try do
        outgoing_notifications =
          Engine.user_notifications(user, summaries_by_key, alerts_by_id, now, global)

        results = localize_notifications(user, outgoing_notifications)
        Logger.info("#{__MODULE__} find_new_notifications_for_user status=ok")
        results
      rescue
        error ->
          log_exception(
            "find_new_notifications_for_user",
            "status=error user_id=#{user.id}",
            Exception.format(:error, error, __STACKTRACE__)
          )

          []
      end
    end)
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
          %{Alert.id() => {AlertSummary.t(), AlertSummary.t()}}

  defp summaries_by_subscription_key(subscription_key, alerts, now, global) do
    {engine_us, relevant_alerts} =
      :timer.tc(
        &Engine.alerts_for_subscription_key/4,
        [subscription_key, alerts, now, global],
        :microsecond
      )

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

          log_alert_summary_type_issues(
            alert,
            summary_no_other_active_alerts,
            patterns,
            schedules
          )

          {alert.id, {summary_no_other_active_alerts, summary_has_multiple_active_alerts}}
        end
      )

    Logger.info("#{__MODULE__} alerts_for_subscription_key duration=#{engine_us}")
    summaries_per_alert
  end

  @spec log_alert_summary_type_issues(Alert.t(), AlertSummary.t(), [RoutePattern.t()], [
          Schedule.t()
        ]) :: :ok
  defp log_alert_summary_type_issues(alert, alert_summary, patterns, schedules) do
    case alert_summary do
      %AlertSummary.Standard{} ->
        if Alert.trip_ids(alert) != [] do
          Logger.warning(
            "Alert #{alert.id} has trips Ids but is summarized as Standard. patterns: #{RoutePattern.ids(patterns)}, schedules: #{Schedule.ids(schedules)}"
          )
        end

      %AlertSummary.TripSpecific{} ->
        if Alert.trip_ids(alert) == [] do
          Logger.warning(
            "Alert #{alert.id} has no trip Ids but is summarized as Trip Specific. patterns: #{RoutePattern.ids(patterns)}, schedules: #{Schedule.ids(schedules)}"
          )
        end

      %AlertSummary.TripShuttle{} ->
        if Alert.trip_ids(alert) == [] do
          Logger.warning(
            "Alert #{alert.id} has no trip Ids but is summarized as Trip Shuttle. patterns: #{RoutePattern.ids(patterns)}, schedules: #{Schedule.ids(schedules)}"
          )
        end

      _ ->
        :ok
    end

    :ok
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
      type: type,
      analytics_label: analytics_label(subscriptions, notification.alert_effect, type),
      metadata: %{subscriptions: subscriptions, locale: notification.locale}
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

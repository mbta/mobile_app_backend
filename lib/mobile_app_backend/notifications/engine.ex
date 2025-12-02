defmodule MobileAppBackend.Notifications.Engine do
  alias MBTAV3API.Alert
  alias MBTAV3API.Alert.ActivePeriod
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window

  @spec notifications([Subscription.t()], [Alert.t()], DateTime.t()) :: [
          {[Subscription.t()], Alert.t(), DeliveredNotification.type()}
        ]
  def notifications(subscriptions, alerts, now) do
    global_data = GlobalDataCache.get_data()

    all_candidates =
      Enum.flat_map(subscriptions, &get_all_candidates(&1, alerts, now, global_data))

    candidates_by_alert =
      Enum.group_by(
        all_candidates,
        fn {alert, _type, _subscription} -> alert end,
        fn {_alert, type, subscription} -> {type, subscription} end
      )

    Enum.map(candidates_by_alert, fn {alert, candidates} ->
      subscriptions_by_type =
        Enum.group_by(
          candidates,
          fn {type, _subscription} -> type end,
          fn {_type, subscription} -> subscription end
        )

      case subscriptions_by_type do
        %{all_clear: subscriptions} ->
          {subscriptions, alert, :all_clear}

        %{notification: subscriptions} ->
          {subscriptions, alert,
           {:notification,
            alert.last_push_notification_timestamp || hd(alert.active_period).start}}

        %{reminder: subscriptions} ->
          {subscriptions, alert, :reminder}
      end
    end)
  end

  defp get_all_candidates(%Subscription{} = subscription, alerts, now, global_data) do
    route_ids =
      case subscription.route_id do
        "line-" <> _ ->
          global_data.routes
          |> Map.values()
          |> Enum.filter(&(&1.line_id == subscription.route_id))
          |> Enum.map(& &1.id)

        _ ->
          [subscription.route_id]
      end

    target_stop_with_children =
      case Stop.parent_if_exists(global_data.stops[subscription.stop_id], global_data.stops) do
        %Stop{id: target_stop_id, child_stop_ids: child_stop_ids} ->
          [target_stop_id | child_stop_ids]

        nil ->
          [subscription.stop_id]
      end

    applicable_alerts =
      applicable_alerts(alerts, subscription, route_ids, target_stop_with_children)

    downstream_alerts =
      downstream_alerts(alerts, route_ids, target_stop_with_children, global_data)

    elevator_alerts =
      if subscription.include_accessibility do
        elevator_alerts(alerts, target_stop_with_children)
      else
        []
      end

    relevant_alerts = Enum.uniq(applicable_alerts ++ downstream_alerts ++ elevator_alerts)

    Enum.flat_map(relevant_alerts, fn %Alert{} = alert ->
      List.wrap(alert_candidate(subscription, alert, now))
    end)
  end

  defp applicable_alerts(
         alerts,
         %Subscription{} = subscription,
         route_ids,
         target_stop_with_children
       ) do
    cr_core? =
      Enum.any?(
        target_stop_with_children,
        &(&1 in ["place-north", "place-sstat", "place-bbsta", "place-rugg"])
      )

    applicable_alerts =
      Alert.applicable_alerts(
        alerts,
        subscription.direction_id,
        route_ids,
        target_stop_with_children,
        nil
      )

    if cr_core? do
      Enum.filter(applicable_alerts, &(&1.effect != :track_change))
    else
      applicable_alerts
    end
  end

  defp downstream_alerts(alerts, route_ids, target_stop_with_children, global_data) do
    route_patterns =
      global_data.route_patterns |> Map.values() |> Enum.filter(&(&1.route_id in route_ids))

    Alert.alerts_downstream_for_patterns(
      alerts,
      route_patterns,
      target_stop_with_children,
      global_data.trips
    )
  end

  defp elevator_alerts(alerts, target_stop_with_children) do
    Alert.elevator_alerts(alerts, target_stop_with_children)
  end

  defp alert_candidate(subscription, alert, now) do
    open_now? = Enum.any?(subscription.windows, &Window.open?(&1, now))
    next_active_in_hours = next_active_in_hours(alert, now)
    active_now? = next_active_in_hours == 0

    cond do
      open_now? and not is_nil(alert.closed_timestamp) -> {alert, :all_clear, subscription}
      open_now? and active_now? -> {alert, :notification, subscription}
      open_now? and next_active_in_hours < 24 -> {alert, :reminder, subscription}
      next_active_in_hours < 12 -> {alert, :reminder, subscription}
      true -> nil
    end
  end

  defp next_active_in_hours(alert, now) do
    for %ActivePeriod{start: ap_start, end: ap_end} <- alert.active_period,
        reduce: nil do
      0 ->
        0

      next_active_in_hours ->
        already_ended? = not is_nil(ap_end) and DateTime.compare(ap_end, now) == :lt

        if already_ended? do
          next_active_in_hours
        else
          starts_in_hours = max(0, DateTime.diff(ap_start, now, :minute) / 60)
          min(starts_in_hours, next_active_in_hours)
        end
    end
  end
end

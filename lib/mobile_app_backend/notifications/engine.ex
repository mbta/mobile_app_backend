defmodule MobileAppBackend.Notifications.Engine do
  require Logger
  alias MBTAV3API.Alert
  alias MBTAV3API.Line
  alias MBTAV3API.Schedule
  alias MBTAV3API.Stop
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertUtil
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.Engine.OutgoingNotification
  alias MobileAppBackend.Notifications.NotificationTitle
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.User

  # Function gets called for a single user at a time from a Oban worker
  @spec user_notifications(
          User.t(),
          %{
            Subscription.key_properties() => %{Alert.id() => {AlertSummary.t(), AlertSummary.t()}}
          },
          %{Alert.id() => Alert.t()},
          DateTime.t(),
          GlobalDataCache.data()
        ) :: [
          OutgoingNotification.t()
        ]
  def user_notifications(user, summaries_by_subscription_key, alerts_by_id, now, global_data) do
    alert_to_matching_subscriptions =
      alert_to_matching_subscriptions(
        user,
        summaries_by_subscription_key,
        alerts_by_id,
        global_data,
        now
      )

    Enum.flat_map(alert_to_matching_subscriptions, fn {alert, {type, subscriptions}} ->
      if is_nil(type) do
        []
      else
        subscription_key_to_alerts =
          subscription_key_to_alerts(summaries_by_subscription_key, alerts_by_id)

        has_more_active_alerts =
          has_more_active_alerts?(alert, subscription_key_to_alerts, subscriptions, now)

        build_outgoing_notification(
          alert,
          subscriptions,
          summaries_by_subscription_key,
          has_more_active_alerts,
          type,
          global_data
        )
      end
    end)
  end

  @spec alert_to_matching_subscriptions(
          User.t(),
          %{
            Subscription.key_properties() => %{Alert.id() => {AlertSummary.t(), AlertSummary.t()}}
          },
          %{Alert.id() => Alert.t()},
          GlobalDataCache.data(),
          DateTime.t()
        ) :: %{
          Alert.t() => {DeliveredNotification.type(), [Subscription.t()]}
        }
  defp alert_to_matching_subscriptions(
         user,
         summaries_by_subscription_key,
         alerts_by_id,
         global_data,
         now
       ) do
    # Only considers key properties, not windows
    alert_to_subscriptions =
      user.notification_subscriptions
      |> Enum.flat_map(fn subscription ->
        subscription_key = Subscription.key_properties(subscription)
        alert_ids = Map.keys(summaries_by_subscription_key[subscription_key])
        Enum.map(alert_ids, fn alert_id -> {alert_id, subscription} end)
      end)
      |> Enum.group_by(fn {alert_id, _subscription} -> alerts_by_id[alert_id] end, fn {_alert_id,
                                                                                       subscription} ->
        subscription
      end)

    alert_to_subscriptions
    |> Map.new(fn {alert, subscriptions} ->
      matching_subscriptions =
        subscriptions
        |> Enum.map(fn subscription ->
          {notification_type(subscription, alert, global_data, now), subscription}
        end)
        |> Enum.group_by(
          fn {type, _subscription} -> type end,
          fn {_type, subscription} -> subscription end
        )
        |> Enum.max_by(
          fn {type, _subscriptions} -> DeliveredNotification.type_priority(type) end,
          fn -> nil end
        )

      {alert, matching_subscriptions}
    end)
  end

  defp subscription_key_to_alerts(summaries_by_subscription_key, alerts_by_id) do
    summaries_by_subscription_key
    |> Map.new(fn {subscription_key, summaries_by_alert_id} ->
      alert_ids =
        summaries_by_alert_id
        |> Map.keys()

      {subscription_key,
       alerts_by_id
       |> Map.take(alert_ids)
       |> Map.values()}
    end)
  end

  @spec alerts_for_subscription_key(
          Subscription.key_properties(),
          [Alert.t()],
          DateTime.t(),
          map()
        ) :: [
          Alert.t()
        ]
  def alerts_for_subscription_key(
        subscription_key,
        alerts,
        now,
        global_data
      ) do
    route_ids =
      case subscription_key.route_id do
        "line-" <> _ ->
          global_data.routes
          |> Map.values()
          |> Enum.filter(&(&1.line_id == subscription_key.route_id))
          |> Enum.map(& &1.id)

        _ ->
          [subscription_key.route_id]
      end

    target_stop_with_children =
      case Stop.parent_if_exists(global_data.stops[subscription_key.stop_id], global_data.stops) do
        %Stop{id: target_stop_id, child_stop_ids: child_stop_ids} ->
          [target_stop_id | child_stop_ids]

        nil ->
          [subscription_key.stop_id]
      end

    alerts = filter_trip_alerts_serving_stop(alerts, now, target_stop_with_children)

    applicable_alerts =
      applicable_alerts(alerts, subscription_key, route_ids, target_stop_with_children)

    downstream_alerts =
      downstream_alerts(alerts, route_ids, target_stop_with_children, global_data)

    elevator_alerts =
      if subscription_key.include_accessibility do
        elevator_alerts(alerts, target_stop_with_children)
      else
        []
      end

    Enum.uniq(applicable_alerts ++ downstream_alerts ++ elevator_alerts)
  end

  @doc """
  Get schedules for the trips affected by the given alert that
  also match the given subscription key.
  """
  @spec schedules_for_alert_trips(
          Alert.t(),
          Subscription.key_properties(),
          GlobalDataCache.data(),
          DateTime.t()
        ) :: [Schedule.t()] | nil
  def schedules_for_alert_trips(alert, subscription_key, global_data, now) do
    schedules_and_trips = AlertUtil.fetch_schedules_for_alert(alert, now)

    case schedules_and_trips do
      {nil, nil} ->
        nil

      {schedules, trips} ->
        Enum.filter(schedules, fn schedule ->
          schedule_matches_subscription_key?(schedule, subscription_key, trips, global_data)
        end)
    end
  end

  defp build_outgoing_notification(
         alert,
         subscriptions,
         summaries_by_subscription_key,
         has_more_active_alerts,
         type,
         global_data
       ) do
    summary =
      build_summary(
        alert,
        subscriptions,
        summaries_by_subscription_key,
        has_more_active_alerts
      )

    if summary do
      [
        %OutgoingNotification{
          title: build_title(alert, subscriptions, global_data),
          summary: summary,
          subscriptions: subscriptions,
          alert: alert,
          type: type
        }
      ]
    else
      Logger.warning(
        "#{__MODULE__} notification_skipped reason=missing_summary #{alert.id} #{Enum.map(subscriptions, &Subscription.key_properties/1)}"
      )

      []
    end
  end

  # Are there other active alerts that affect the same subscriptions as the given alert?
  # Excludes elevator closures
  @spec has_more_active_alerts?(
          Alert.t(),
          %{Subscription.key_properties() => [Alert.t()]},
          [Subscription.t()],
          DateTime.t()
        ) :: boolean()
  defp has_more_active_alerts?(
         alert,
         subscription_key_to_alerts,
         subscriptions_matching_alert,
         now
       ) do
    target_keys = Enum.map(subscriptions_matching_alert, &Subscription.key_properties(&1))

    subscription_key_to_alerts
    |> Map.take(target_keys)
    |> Map.values()
    |> List.flatten()
    |> Enum.count(
      &(&1.id != alert.id &&
          &1.effect != :elevator_closure &&
          Alert.active?(&1, now))
    ) > 0
  end

  defp filter_trip_alerts_serving_stop(alerts, now, target_stop_with_children) do
    trips = AlertUtil.fetch_trips_for_alerts(alerts, now)

    if Enum.empty?(trips) do
      alerts
    else
      target_stop_set = MapSet.new(target_stop_with_children)
      trip_by_id = Map.new(trips, &{&1.id, MapSet.new(&1.stop_ids)})

      Enum.filter(alerts, fn %Alert{} = alert ->
        alert
        |> Alert.trip_ids()
        |> Enum.empty?() ||
          trip_alert_serves_stop(alert, trip_by_id, target_stop_set)
      end)
    end
  end

  defp trip_alert_serves_stop(%Alert{} = alert, trip_by_id, target_stop_set) do
    Alert.any_informed_entity_satisfies(alert, fn ie ->
      trip_id = ie.trip

      trip_stop_ids = Map.get(trip_by_id, trip_id)

      trip_stop_ids != nil &&
        trip_stop_ids
        |> MapSet.intersection(target_stop_set)
        |> MapSet.size() > 0
    end)
  end

  defp applicable_alerts(
         alerts,
         subscription,
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

  @spec notification_type(Subscription.t(), Alert.t(), GlobalDataCache.data(), DateTime.t()) ::
          DeliveredNotification.type() | nil
  # this is not actually particularly complicated
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp notification_type(subscription, alert, global_data, now) do
    open_now? = Enum.any?(subscription.windows, &Window.open?(&1, now))

    trip_times = trip_times(subscription, alert, global_data, now)

    overlap_targets =
      if trip_times != nil do
        trip_times
      else
        alert.active_period
      end

    next_overlap =
      Window.next_overlap(overlap_targets, subscription.windows, now)

    next_overlap_in_hours = if next_overlap, do: DateTime.diff(next_overlap, now, :minute) / 60
    active_now? = next_overlap_in_hours <= 0

    cond do
      open_now? and Alert.all_clear?(alert) ->
        if can_send?(subscription, alert, :all_clear) do
          :all_clear
        else
          nil
        end

      is_nil(next_overlap) ->
        nil

      open_now? and active_now? and
          can_send?(
            subscription,
            alert,
            {:notification, alert.last_push_notification_timestamp}
          ) ->
        {:notification, alert.last_push_notification_timestamp}

      open_now? and active_now? and
          can_send?(
            subscription,
            alert,
            {:update, alert.last_push_notification_timestamp}
          ) ->
        {:update, alert.last_push_notification_timestamp}

      open_now? and active_now? ->
        nil

      open_now? and next_overlap_in_hours < 24 and
          can_send?(subscription, alert, :reminder) ->
        :reminder

      next_overlap_in_hours < 12 and
          can_send?(subscription, alert, :reminder) ->
        :reminder

      true ->
        nil
    end
  end

  defp can_send?(subscription, alert, type) do
    DeliveredNotification.can_send?(subscription.user_id, alert.id, type)
  end

  defp build_title(alert, subscriptions, global_data) do
    subscribed_line_or_route_ids = subscriptions |> Enum.map(& &1.route_id) |> Enum.uniq()

    subscribed_lines_or_routes =
      Enum.map(subscribed_line_or_route_ids, &(global_data.lines[&1] || global_data.routes[&1]))

    title_lines_or_routes =
      Enum.map(subscribed_lines_or_routes, fn
        %Line{} = line ->
          # we narrow a subscription to `line-Green` to a title of “Green Line B” if only one route is informed,
          # but we use the full line if multiple routes within it are informed

          informed_routes =
            global_data.routes
            |> Map.values()
            |> Enum.filter(fn route ->
              route.line_id == line.id and
                Enum.any?(
                  alert.informed_entity,
                  &(&1.route == route.id or (&1.route == nil and &1.route_type == route.type))
                )
            end)

          case informed_routes do
            [route] -> route
            _ -> line
          end

        route ->
          route
      end)

    NotificationTitle.from_lines_or_routes(title_lines_or_routes)
  end

  defp build_summary(
         alert,
         [subscription],
         summaries_by_subscription_key,
         has_multiple_active_alerts
       ) do
    summary_for_subscription(
      alert,
      subscription,
      summaries_by_subscription_key,
      has_multiple_active_alerts
    )
  end

  defp build_summary(
         alert,
         subscriptions,
         summaries_by_subscription_key,
         has_multiple_active_alerts
       ) do
    individual_summaries =
      Enum.map(subscriptions, fn subscription ->
        summary_for_subscription(
          alert,
          subscription,
          summaries_by_subscription_key,
          has_multiple_active_alerts
        )
      end)

    AlertSummary.combine_summaries(alert, individual_summaries)
  end

  defp summary_for_subscription(
         alert,
         subscription,
         summaries_by_subscription_key,
         has_multiple_active_alerts
       ) do
    {no_other_active_alert_summary, has_multiple_active_alerts_summary} =
      get_in(summaries_by_subscription_key, [
        Subscription.key_properties(subscription),
        alert.id
      ])

    if has_multiple_active_alerts do
      has_multiple_active_alerts_summary
    else
      no_other_active_alert_summary
    end
  end

  defp schedule_matches_subscription_key?(
         %Schedule{} = schedule,
         subscription,
         trips,
         global_data
       ) do
    route_matches? =
      schedule.route_id == subscription.route_id or
        global_data.routes[schedule.route_id].line_id == subscription.route_id

    stop_matches? =
      schedule.stop_id == subscription.stop_id or
        global_data.stops[schedule.stop_id].parent_station_id == subscription.stop_id

    direction_matches? =
      trips[schedule.trip_id].direction_id == subscription.direction_id

    route_matches? and stop_matches? and direction_matches?
  end

  defp trip_times(subscription, alert, global_data, now) do
    schedules =
      schedules_for_alert_trips(
        alert,
        Subscription.key_properties(subscription),
        global_data,
        now
      )

    if schedules != nil do
      schedules
      |> Enum.map(&(&1.departure_time || &1.arrival_time))
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)
    else
      nil
    end
  end
end

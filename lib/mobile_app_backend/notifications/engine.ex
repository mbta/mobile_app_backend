defmodule MobileAppBackend.Notifications.Engine do
  require Logger
  alias MBTAV3API.Alert
  alias MBTAV3API.Line
  alias MBTAV3API.RoutePattern
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

  @slow_step_threshold_us 10_000

  @cr_core MapSet.new(["place-north", "place-sstat", "place-bbsta", "place-rugg"])

  # Function gets called for a single user at a time from a Oban worker
  @spec user_notifications([Subscription.t()], [Alert.t()], DateTime.t()) :: [
          OutgoingNotification.t()
        ]
  def user_notifications(subscriptions, alerts, now) do
    {global_data_us, global_data} =
      :timer.tc(&GlobalDataCache.get_data/0, :microsecond)

    log_slow_step("global_data", global_data_us)

    {relevance_us, relevant_alerts_by_subscription} =
      :timer.tc(
        fn ->
          Enum.map(subscriptions, fn subscription ->
            {subscription_us, relevant_alerts} =
              :timer.tc(
                fn ->
                  extract_relevant_alerts_for_subscription(alerts, subscription, now, global_data)
                end,
                :microsecond
              )

            log_slow_step("extract_relevant_alerts", subscription_us)

            {subscription, relevant_alerts}
          end)
        end,
        :microsecond
      )

    log_slow_step("relevance", relevance_us)

    {candidate_us, all_candidates} =
      :timer.tc(
        fn ->
          Enum.flat_map(relevant_alerts_by_subscription, fn {subscription, relevant_alerts} ->
            {subscription_us, candidates} =
              :timer.tc(
                fn -> get_all_candidates(subscription, relevant_alerts, now) end,
                :microsecond
              )

            log_slow_step("evaluate_candidates", subscription_us)

            candidates
          end)
        end,
        :microsecond
      )

    log_slow_step("candidate_evaluation", candidate_us)

    {grouping_us, candidates_by_alert} =
      :timer.tc(
        fn ->
          Enum.group_by(
            all_candidates,
            fn {alert, _type, _subscription} -> alert end,
            fn {_alert, type, subscription} -> {type, subscription} end
          )
        end,
        :microsecond
      )

    log_slow_step("candidate_grouping", grouping_us)

    {notification_us, notifications} =
      :timer.tc(
        fn ->
          Enum.map(candidates_by_alert, fn {alert, candidates} ->
            {notification_build_us, notification} =
              :timer.tc(
                fn ->
                  subscriptions_by_type =
                    Enum.group_by(
                      candidates,
                      fn {type, _subscription} -> type end,
                      fn {_type, subscription} -> subscription end
                    )

                  # Get subscriptions of the a single type for the alert
                  {subscriptions, type} =
                    case subscriptions_by_type do
                      %{all_clear: subscriptions} ->
                        {subscriptions, :all_clear}

                      %{notification: subscriptions} ->
                        {subscriptions, {:notification, alert.last_push_notification_timestamp}}

                      %{update: subscriptions} ->
                        {subscriptions, {:update, alert.last_push_notification_timestamp}}

                      %{reminder: subscriptions} ->
                        {subscriptions, :reminder}
                    end

                  relevant_alerts =
                    relevant_alerts_by_subscription
                    |> Enum.filter(fn {subscription, _relevant_alerts} ->
                      subscription in subscriptions
                    end)
                    |> Enum.flat_map(fn {_subscription, relevant_alerts} -> relevant_alerts end)

                  Logger.debug(
                    "#{__MODULE__} relevant_alerts=[#{relevant_alerts |> Enum.map_join(",", & &1.id)}]"
                  )

                  more_active_alerts =
                    relevant_alerts
                    |> Enum.count(
                      # Elevator closures should not be considered as part of other active
                      &(&1.id != alert.id &&
                          &1.effect != :elevator_closure &&
                          Alert.active?(&1, now))
                    ) > 0

                  %OutgoingNotification{
                    title: build_title(alert, subscriptions, global_data),
                    summary:
                      build_summary(alert, subscriptions, now, global_data, more_active_alerts),
                    subscriptions: subscriptions,
                    alert: alert,
                    type: type
                  }
                end,
                :microsecond
              )

            log_slow_step("build_notification", notification_build_us)

            notification
          end)
        end,
        :microsecond
      )

    log_slow_step("notification_build", notification_us)

    notifications
  end

  defp get_all_candidates(%Subscription{} = subscription, relevant_alerts, now) do
    relevant_alerts =
      relevant_alerts
      |> Enum.filter(&Alert.eligible_for_notification?(&1))

    Enum.flat_map(relevant_alerts, fn %Alert{} = alert ->
      List.wrap(alert_candidate(subscription, alert, now))
    end)
  end

  defp extract_relevant_alerts_for_subscription(
         alerts,
         %Subscription{} = subscription,
         now,
         global_data
       ) do
    route_ids =
      case subscription.route_id do
        "line-" <> _ ->
          global_data.routes_by_line[subscription.route_id]

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

    alerts = filter_trip_alerts_serving_stop(alerts, now, target_stop_with_children)

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

    [applicable_alerts, downstream_alerts, elevator_alerts]
    |> List.flatten()
    |> Enum.uniq_by(& &1.id)
  end

  defp filter_trip_alerts_serving_stop(alerts, now, target_stop_with_children) do
    {trip_fetch_us, trips} =
      :timer.tc(fn -> AlertUtil.fetch_trips_for_alerts(alerts, now) end, :microsecond)

    log_slow_step("fetch_trips_for_alerts", trip_fetch_us)

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
         %Subscription{} = subscription,
         route_ids,
         target_stop_with_children
       ) do
    target_stop_set = MapSet.new(target_stop_with_children)

    cr_core? =
      target_stop_set
      |> MapSet.intersection(@cr_core)
      |> MapSet.size() > 0

    alerts =
      if cr_core? do
        Enum.filter(alerts, &(&1.effect != :track_change))
      else
        alerts
      end

    Alert.applicable_alerts(
      alerts,
      subscription.direction_id,
      route_ids,
      target_stop_with_children,
      nil
    )
  end

  @spec downstream_alerts([Alert.t()], [Route.id()], [Stop.id()], GlobalDataCache.data()) :: [
          Alert.t()
        ]
  defp downstream_alerts(alerts, route_ids, target_stop_with_children, global_data) do
    pattern_ids =
      global_data.route_patterns_by_route
      |> Map.take(route_ids)
      |> Map.values()
      |> List.flatten()

    route_patterns =
      global_data.route_patterns
      |> Map.take(pattern_ids)
      |> Map.values()

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

  # this is not actually particularly complicated
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp alert_candidate(subscription, alert, now) do
    open_now? = Enum.any?(subscription.windows, &Window.open?(&1, now))

    next_overlap = Window.next_overlap(alert.active_period, subscription.windows, now)
    next_overlap_in_hours = if next_overlap, do: DateTime.diff(next_overlap, now, :minute) / 60
    active_now? = next_overlap_in_hours <= 0

    cond do
      open_now? and Alert.all_clear?(alert) ->
        {alert, :all_clear, subscription}

      is_nil(next_overlap) ->
        nil

      open_now? and active_now? and
          can_send_for_candidate?(
            subscription,
            alert,
            {:notification, alert.last_push_notification_timestamp}
          ) ->
        {alert, :notification, subscription}

      open_now? and active_now? and
          can_send_for_candidate?(
            subscription,
            alert,
            {:update, alert.last_push_notification_timestamp}
          ) ->
        {alert, :update, subscription}

      open_now? and active_now? ->
        nil

      open_now? and next_overlap_in_hours < 24 and
          can_send_for_candidate?(subscription, alert, :reminder) ->
        {alert, :reminder, subscription}

      next_overlap_in_hours < 12 and
          can_send_for_candidate?(subscription, alert, :reminder) ->
        {alert, :reminder, subscription}

      true ->
        nil
    end
  end

  defp can_send_for_candidate?(subscription, alert, type) do
    {query_us, can_send?} =
      :timer.tc(
        fn ->
          DeliveredNotification.can_send?(subscription.user_id, alert.id, type)
        end,
        :microsecond
      )

    log_slow_step("delivered_notification_check", query_us)

    can_send?
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

  defp build_summary(alert, [subscription], now, global_data, has_multiple_active_alerts) do
    summary_for_subscription(alert, subscription, now, global_data, has_multiple_active_alerts)
  end

  defp build_summary(alert, subscriptions, now, global_data, has_multiple_active_alerts) do
    individual_summaries =
      Enum.map(subscriptions, fn subscription ->
        summary_for_subscription(
          alert,
          subscription,
          now,
          global_data,
          has_multiple_active_alerts
        )
      end)

    AlertSummary.combine_summaries(alert, individual_summaries)
  end

  defp summary_for_subscription(alert, subscription, now, global_data, has_multiple_active_alerts) do
    patterns =
      RoutePattern.get_relevant_patterns(
        subscription.route_id,
        subscription.stop_id,
        subscription.direction_id,
        global_data
      )

    schedules = schedules_for_subscription(alert, subscription, global_data, now)

    AlertSummary.summarizing(
      alert,
      subscription,
      patterns,
      now,
      schedules,
      global_data,
      :notification,
      has_multiple_active_alerts
    )
  end

  defp schedules_for_subscription(alert, subscription, global_data, now) do
    {schedule_fetch_us, schedules_and_trips} =
      :timer.tc(fn -> AlertUtil.fetch_schedules_for_alert(alert, now) end, :microsecond)

    log_slow_step("fetch_schedules_for_alert", schedule_fetch_us)

    case schedules_and_trips do
      {nil, nil} ->
        nil

      {schedules, trips} ->
        Enum.filter(schedules, fn schedule ->
          schedule_matches_subscription?(schedule, subscription, trips, global_data)
        end)
    end
  end

  defp log_slow_step(step, duration_us) when duration_us >= @slow_step_threshold_us do
    duration_ms = Float.round(duration_us / 1_000, 2)
    Logger.info("step=#{step} duration_ms=#{duration_ms}")
  end

  defp log_slow_step(_step, _duration_us), do: :ok

  defp schedule_matches_subscription?(
         %Schedule{} = schedule,
         %Subscription{} = subscription,
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

    trip_time = schedule.departure_time || schedule.arrival_time
    time_matches? = Enum.any?(subscription.windows, &Window.open?(&1, trip_time))

    route_matches? and stop_matches? and direction_matches? and time_matches?
  end
end

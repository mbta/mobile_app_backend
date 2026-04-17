defmodule MobileAppBackend.Notifications.Engine do
  alias MBTAV3API.Alert
  alias MBTAV3API.Line
  alias MBTAV3API.Repository
  alias MBTAV3API.Schedule
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.NotificationTitle
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window

  defmodule OutgoingNotification do
    @type t :: %__MODULE__{
            title: NotificationTitle.t(),
            summary: AlertSummary.t(),
            subscriptions: [Subscription.t()],
            alert: Alert.t(),
            type: DeliveredNotification.type()
          }
    defstruct [:title, :summary, :subscriptions, :alert, :type]
  end

  @spec notifications([Subscription.t()], [Alert.t()], DateTime.t()) :: [OutgoingNotification.t()]
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

      {subscriptions, type} =
        case subscriptions_by_type do
          %{all_clear: subscriptions} ->
            {subscriptions, :all_clear}

          %{notification: subscriptions} ->
            {subscriptions,
             {:notification,
              alert.last_push_notification_timestamp || hd(alert.active_period).start}}

          %{reminder: subscriptions} ->
            {subscriptions, :reminder}
        end

      summary =
        if Alert.any_informed_entity_satisfies(alert, fn ie ->
             ie.route == "131"
           end) do
          %{fallback: "This is a fallback alert message", effect: "This is a fake effect"}
        else
          build_summary(alert, subscriptions, now, global_data)
        end

      %OutgoingNotification{
        title: build_title(alert, subscriptions, global_data),
        summary: summary,
        subscriptions: subscriptions,
        alert: alert,
        type: type
      }
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

  # this is not actually particularly complicated
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp alert_candidate(subscription, alert, now) do
    open_now? = Enum.any?(subscription.windows, &Window.open?(&1, now))

    next_overlap = Window.next_overlap(alert.active_period, subscription.windows, now)
    next_overlap_in_hours = if next_overlap, do: DateTime.diff(next_overlap, now, :minute) / 60
    active_now? = next_overlap_in_hours <= 0

    cond do
      open_now? and not is_nil(alert.closed_timestamp) and
          alert.closed_timestamp == alert.last_push_notification_timestamp ->
        {alert, :all_clear, subscription}

      is_nil(next_overlap) ->
        nil

      open_now? and active_now? ->
        {alert, :notification, subscription}

      open_now? and next_overlap_in_hours < 24 ->
        {alert, :reminder, subscription}

      next_overlap_in_hours < 12 ->
        {alert, :reminder, subscription}

      true ->
        nil
    end
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

  defp build_summary(alert, [subscription], now, global_data) do
    summary_for_subscription(alert, subscription, now, global_data)
  end

  defp build_summary(alert, subscriptions, now, global_data) do
    individual_summaries =
      Enum.map(subscriptions, fn subscription ->
        summary_for_subscription(alert, subscription, now, global_data)
      end)

    AlertSummary.combine_summaries(alert, individual_summaries)
  end

  defp summary_for_subscription(alert, subscription, now, global_data) do
    patterns =
      global_data.route_patterns
      |> Stream.map(fn {_, pattern} -> pattern end)
      |> Enum.filter(fn pattern ->
        (pattern.route_id == subscription.route_id or
           global_data.routes[pattern.route_id].line_id == subscription.route_id) and
          pattern.direction_id == subscription.direction_id and
          Enum.any?(
            with trip_id when is_binary(trip_id) <- pattern.representative_trip_id,
                 %Trip{} = trip <- global_data.trips[trip_id] do
              trip.stop_ids
            else
              _ -> []
            end,
            &(&1 == subscription.stop_id or
                &1 in global_data.stops[subscription.stop_id].child_stop_ids)
          )
      end)

    schedules = schedules_for_subscription(alert, subscription, global_data)

    AlertSummary.summarizing(
      alert,
      subscription.stop_id,
      subscription.direction_id,
      patterns,
      now,
      schedules,
      global_data
    )
  end

  defp schedules_for_subscription(alert, subscription, global_data) do
    trip_ids =
      alert.informed_entity |> Enum.map(& &1.trip) |> Enum.uniq() |> Enum.reject(&is_nil/1)

    case trip_ids do
      [] ->
        nil

      trip_ids ->
        {:ok, %{data: schedules, included: %{trips: trips}}} =
          Repository.schedules(
            filter: [trip: trip_ids],
            include: :trip,
            sort: {:stop_sequence, :asc}
          )

        schedules =
          Enum.filter(schedules, fn schedule ->
            schedule_matches_subscription?(schedule, subscription, trips, global_data)
          end)

        schedules
    end
  end

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
    time = DateTime.to_time(trip_time)
    day = Date.day_of_week(trip_time)

    time_matches? =
      Enum.any?(subscription.windows, fn %Window{} = window ->
        Time.compare(window.start_time, time) != :gt and
          Time.compare(time, window.end_time) != :gt and day in window.days_of_week
      end)

    route_matches? and stop_matches? and direction_matches? and time_matches?
  end
end

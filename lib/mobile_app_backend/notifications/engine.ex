defmodule MobileAppBackend.Notifications.Engine do
  alias MBTAV3API.Alert
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.Subscription

  def matches?(%Alert{} = alert, %Subscription{} = subscription) do
    global_data = GlobalDataCache.get_data()

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

    if Alert.compare_significance(Alert.significance(alert), :minor) == :lt do
      false
    else
      applicable? = applicable?(alert, subscription, route_ids, target_stop_with_children)
      downstream? = downstream?(alert, route_ids, target_stop_with_children, global_data)

      elevator? =
        subscription.include_accessibility and elevator?(alert, target_stop_with_children)

      applicable? or downstream? or elevator?
    end
  end

  defp applicable?(
         %Alert{} = alert,
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
        [alert],
        subscription.direction_id,
        route_ids,
        target_stop_with_children,
        nil
      )

    applicable_alerts =
      if cr_core? do
        Enum.filter(applicable_alerts, &(&1.effect != :track_change))
      else
        applicable_alerts
      end

    applicable_alerts == [alert]
  end

  defp downstream?(%Alert{} = alert, route_ids, target_stop_with_children, global_data) do
    route_patterns =
      global_data.route_patterns |> Map.values() |> Enum.filter(&(&1.route_id in route_ids))

    Alert.alerts_downstream_for_patterns(
      [alert],
      route_patterns,
      target_stop_with_children,
      global_data.trips
    ) == [alert]
  end

  defp elevator?(%Alert{} = alert, target_stop_with_children) do
    Alert.elevator_alerts([alert], target_stop_with_children) == [alert]
  end
end

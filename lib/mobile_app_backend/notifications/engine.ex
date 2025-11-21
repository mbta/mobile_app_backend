defmodule MobileAppBackend.Notifications.Engine do
  alias MBTAV3API.Alert
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.Subscription

  def matches?(%Alert{} = alert, %Subscription{} = subscription) do
    downstream? = downstream?(alert, subscription)

    Enum.any?(alert.informed_entity, fn %Alert.InformedEntity{} = ie ->
      matches_direction?(ie.direction_id, subscription.direction_id) and
        matches_route?(ie.route, subscription.route_id) and
        (matches_stop?(ie.stop, subscription.stop_id) or downstream?)
    end)
  end

  defp matches_direction?(alert_direction, subscription_direction)

  defp matches_direction?(nil, _), do: true

  defp matches_direction?(alert_direction, subscription_direction) do
    alert_direction == subscription_direction
  end

  defp matches_route?(alert_route, subscription_route)

  defp matches_route?(nil, _), do: true
  defp matches_route?("Green-" <> _, "line-Green"), do: true
  defp matches_route?(alert_route, subscription_route), do: alert_route == subscription_route

  defp matches_stop?(alert_stop, subscription_stop)

  defp matches_stop?(nil, _), do: true
  defp matches_stop?(stop, stop), do: true

  defp matches_stop?(alert_stop, subscription_stop) do
    global_data = GlobalDataCache.get_data()

    alert_root_stop =
      case Map.fetch(global_data.stops, alert_stop) do
        {:ok, %Stop{parent_station_id: parent}} when not is_nil(parent) -> parent
        _ -> alert_stop
      end

    subscription_root_stop =
      case Map.fetch(global_data.stops, subscription_stop) do
        {:ok, %Stop{parent_station_id: parent}} when not is_nil(parent) -> parent
        _ -> subscription_stop
      end

    alert_root_stop == subscription_root_stop
  end

  defp downstream?(%Alert{} = alert, %Subscription{} = subscription) do
    global_data = GlobalDataCache.get_data()

    route_patterns =
      case subscription.route_id do
        "line-" <> _ ->
          routes =
            global_data.routes
            |> Map.values()
            |> Enum.filter(&(&1.line_id == subscription.route_id))
            |> Enum.map(& &1.id)

          global_data.route_patterns |> Map.values() |> Enum.filter(&(&1.route_id in routes))

        _ ->
          global_data.route_patterns
          |> Map.values()
          |> Enum.filter(&(&1.route_id == subscription.route_id))
      end

    target_stop_with_children =
      case Stop.parent_if_exists(global_data.stops[subscription.stop_id], global_data.stops) do
        %Stop{id: target_stop_id, child_stop_ids: child_stop_ids} ->
          [target_stop_id | child_stop_ids]

        nil ->
          []
      end

    Alert.alerts_downstream_for_patterns(
      [alert],
      route_patterns,
      target_stop_with_children,
      global_data.trips
    ) == [alert]
  end
end

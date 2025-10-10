defmodule MobileAppBackend.Notifications.Engine do
  alias MBTAV3API.Alert
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.Subscription

  def matches?(%Alert{} = alert, %Subscription{} = subscription) do
    Enum.any?(alert.informed_entity, fn %Alert.InformedEntity{} = ie ->
      matches_direction?(ie.direction_id, subscription.direction_id) and
        matches_route?(ie.route, subscription.route_id) and
        matches_stop?(ie.stop, subscription.stop_id)
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
end

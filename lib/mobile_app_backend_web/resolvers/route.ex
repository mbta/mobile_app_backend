defmodule MobileAppBackendWeb.Resolvers.Route do
  def by_stop(%Stops.Stop{id: stop_id}, _args, _resolution) do
    {:ok,
     Routes.Repo.by_stop_with_route_pattern(stop_id)
     |> Enum.map(fn {route, route_patterns} -> Map.put(route, :route_patterns, route_patterns) end)}
  end
end

defmodule MobileAppBackendWeb.GlobalController do
  alias MBTAV3API.{JsonApi, Repository}
  use MobileAppBackendWeb, :controller

  @type stop_map() :: MBTAV3API.Stop.stop_map()

  def show(conn, _params) do
    stops = fetch_stops()
    {route_patterns, pattern_ids_by_stop, routes} = fetch_route_patterns()

    json(conn, %{
      stops: stops,
      route_patterns: route_patterns,
      pattern_ids_by_stop: pattern_ids_by_stop,
      routes: routes
    })
  end

  @spec fetch_stops() :: [MBTAV3API.Stop.t()]
  defp fetch_stops do
    {:ok, stops} =
      Repository.stops(
        filter: [
          location_type: [:stop, :station]
        ],
        include: [:parent_station]
      )

    stops
  end

  @spec fetch_route_patterns() ::
          {%{(route_pattern_id :: String.t()) => MBTAV3API.RoutePattern.t()},
           %{(stop_id :: String.t()) => route_pattern_ids :: [String.t()]},
           %{(route_id :: String.t()) => MBTAV3API.Route.t()}}
  defp fetch_route_patterns do
    {:ok, route_patterns} =
      Repository.route_patterns(
        include: [:route, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop = MBTAV3API.RoutePattern.get_pattern_ids_by_stop(route_patterns)
    routes = MBTAV3API.RoutePattern.get_route_map(route_patterns)

    route_patterns =
      Map.new(
        route_patterns,
        &{&1.id,
         %MBTAV3API.RoutePattern{
           &1
           | route: %JsonApi.Reference{type: "route", id: &1.route.id},
             representative_trip: nil
         }}
      )

    {route_patterns, pattern_ids_by_stop, routes}
  end
end

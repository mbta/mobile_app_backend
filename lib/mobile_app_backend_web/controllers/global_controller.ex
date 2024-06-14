defmodule MobileAppBackendWeb.GlobalController do
  alias MBTAV3API.{JsonApi, Repository}
  use MobileAppBackendWeb, :controller

  def show(conn, _params) do
    stops = fetch_stops()

    %{
      lines: lines,
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    } = fetch_route_patterns()

    json(conn, %{
      lines: lines,
      pattern_ids_by_stop: pattern_ids_by_stop,
      routes: routes,
      route_patterns: route_patterns,
      stops: stops,
      trips: trips
    })
  end

  @spec fetch_stops() :: JsonApi.Object.stop_map()
  defp fetch_stops do
    {:ok, %{data: stops}} =
      Repository.stops(
        filter: [
          location_type: [:stop, :station]
        ],
        include: [:child_stops, :connecting_stops, :parent_station]
      )

    Map.new(stops, &{&1.id, &1})
  end

  @spec fetch_route_patterns() :: %{
          lines: JsonApi.Object.line_map(),
          routes: JsonApi.Object.route_map(),
          route_patterns: JsonApi.Object.route_pattern_map(),
          trips: JsonApi.Object.trip_map(),
          pattern_ids_by_stop: %{(stop_id :: String.t()) => route_pattern_ids :: [String.t()]}
        }
  defp fetch_route_patterns do
    {:ok, %{data: route_patterns, included: %{lines: lines, routes: routes, trips: trips}}} =
      Repository.route_patterns(
        include: [route: :line, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop = MBTAV3API.RoutePattern.get_pattern_ids_by_stop(route_patterns, trips)

    trips = Map.new(trips, fn {trip_id, trip} -> {trip_id, trip} end)

    route_patterns = Map.new(route_patterns, &{&1.id, &1})

    %{
      lines: lines,
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    }
  end
end

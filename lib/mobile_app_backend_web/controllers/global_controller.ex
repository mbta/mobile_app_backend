defmodule MobileAppBackendWeb.GlobalController do
  alias MBTAV3API.{JsonApi, Repository}
  use MobileAppBackendWeb, :controller

  def show(conn, _params) do
    stops = fetch_stops()

    %{
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    } = fetch_route_patterns()

    stops = Map.values(stops)

    json(conn, %{
      stops: stops,
      route_patterns: route_patterns,
      pattern_ids_by_stop: pattern_ids_by_stop,
      routes: routes,
      trips: trips
    })
  end

  @spec fetch_stops() :: JsonApi.Object.stop_map()
  defp fetch_stops do
    {:ok, %{stops: stops}} =
      Repository.stops(
        filter: [
          location_type: [:stop, :station]
        ],
        include: [:parent_station]
      )

    stops
  end

  @spec fetch_route_patterns() :: %{
          routes: JsonApi.Object.route_map(),
          route_patterns: JsonApi.Object.route_pattern_map(),
          trips: JsonApi.Object.trip_map(),
          pattern_ids_by_stop: %{(stop_id :: String.t()) => route_pattern_ids :: [String.t()]}
        }
  defp fetch_route_patterns do
    {:ok, %{routes: routes, route_patterns: route_patterns, trips: trips}} =
      Repository.route_patterns(
        include: [:route, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop = MBTAV3API.RoutePattern.get_pattern_ids_by_stop(route_patterns, trips)

    trips =
      Map.new(trips, fn {trip_id, trip} -> {trip_id, %MBTAV3API.Trip{trip | stop_ids: nil}} end)

    %{
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    }
  end
end

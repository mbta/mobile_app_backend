defmodule MobileAppBackendWeb.StopController do
  use MobileAppBackendWeb, :controller

  @type stop_map() :: MBTAV3API.Stop.stop_map()

  def show(conn, _params) do
    stops = fetch_all_stops()
    {route_patterns, pattern_ids_by_stop} = fetch_all_route_patterns()

    json(conn, %{
      stops: stops,
      route_patterns: route_patterns,
      pattern_ids_by_stop: pattern_ids_by_stop
    })
  end

  @spec fetch_all_stops() :: [MBTAV3API.Stop.t()]
  defp fetch_all_stops do
    {:ok, stops} =
      MBTAV3API.Stop.get_all(
        filter: [
          location_type: [:stop, :station]
        ],
        include: [:parent_station]
      )

    stops
  end

  @spec fetch_all_route_patterns() ::
          {%{String.t() => MBTAV3API.RoutePattern.t()}, %{String.t() => [String.t()]}}
  defp fetch_all_route_patterns do
    {:ok, route_patterns} =
      MBTAV3API.RoutePattern.get_all(
        include: [:route, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop = MBTAV3API.RoutePattern.get_pattern_ids_by_stop(route_patterns)

    route_patterns =
      Map.new(route_patterns, &{&1.id, %MBTAV3API.RoutePattern{&1 | representative_trip: nil}})

    {route_patterns, pattern_ids_by_stop}
  end
end

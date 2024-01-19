defmodule MobileAppBackendWeb.NearbyController do
  use MobileAppBackendWeb, :controller

  def show(conn, params) do
    {:ok, stops} =
      MBTAV3API.Stop.get_all(
        filter: [
          latitude: String.to_float(params["latitude"]),
          longitude: String.to_float(params["longitude"]),
          location_type: [0, 1],
          radius: miles_to_degrees(0.5)
        ],
        include: :parent_station,
        sort: {:distance, :asc}
      )

    stops =
      stops
      |> Enum.map(&MBTAV3API.Stop.parent/1)
      |> Enum.uniq()

    {:ok, route_patterns} =
      MBTAV3API.RoutePattern.get_all(
        filter: [stop: Enum.map_join(stops, ",", & &1.id)],
        include: [:route, representative_trip: :stops],
        fields: [stop: []]
      )

    stop_patterns =
      route_patterns
      |> Enum.flat_map(fn
        %MBTAV3API.RoutePattern{
          id: route_pattern_id,
          representative_trip: %MBTAV3API.Trip{stops: stops}
        } ->
          Enum.map(stops, &%{stop_id: &1.id, route_pattern_id: route_pattern_id})
      end)
      |> Enum.group_by(& &1.stop_id, & &1.route_pattern_id)

    route_patterns =
      Map.new(route_patterns, &{&1.id, %MBTAV3API.RoutePattern{&1 | representative_trip: nil}})

    json(conn, %{stops: stops, stop_patterns: stop_patterns, route_patterns: route_patterns})
  end

  # The V3 API does not actually calculate distance,
  # and it just pretends latitude degrees and longitude degrees are equally sized.
  # See https://github.com/mbta/api/blob/1671ba02d4669827fb2a58966d8c3ab39c939b0e/apps/api_web/lib/api_web/controllers/stop_controller.ex#L27-L31.
  # For now, this is fine.
  defp miles_to_degrees(miles), do: miles * 0.02
end

defmodule MobileAppBackendWeb.NearbyController do
  use MobileAppBackendWeb, :controller

  def show(conn, params) do
    params = Map.merge(%{"source" => "otp", "radius" => "0.5"}, params)
    latitude = String.to_float(Map.fetch!(params, "latitude"))
    longitude = String.to_float(Map.fetch!(params, "longitude"))
    radius = String.to_float(Map.fetch!(params, "radius"))

    source =
      case Map.fetch!(params, "source") do
        "v3" -> :v3
        "otp" -> :otp
      end

    stops =
      case source do
        :v3 ->
          {:ok, stops} =
            MBTAV3API.Stop.get_all(
              filter: [
                latitude: latitude,
                longitude: longitude,
                location_type: [0, 1],
                radius: miles_to_degrees(radius)
              ],
              include: :parent_station,
              sort: {:distance, :asc}
            )

          stops

        :otp ->
          {:ok, stops} =
            OpenTripPlannerClient.nearby(latitude, longitude, miles_to_meters(radius))

          stops
      end

    stop_ids = MapSet.new(stops, & &1.id)

    {:ok, route_patterns} =
      MBTAV3API.RoutePattern.get_all(
        filter: [stop: Enum.join(stop_ids, ",")],
        include: [:route, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop =
      route_patterns
      |> Enum.flat_map(fn
        %MBTAV3API.RoutePattern{
          id: route_pattern_id,
          representative_trip: %MBTAV3API.Trip{stops: stops}
        } ->
          stops
          |> Enum.filter(&(&1.id in stop_ids))
          |> Enum.map(&%{stop_id: &1.id, route_pattern_id: route_pattern_id})
      end)
      |> Enum.group_by(& &1.stop_id, & &1.route_pattern_id)

    route_patterns =
      Map.new(route_patterns, &{&1.id, %MBTAV3API.RoutePattern{&1 | representative_trip: nil}})

    json(conn, %{
      stops: stops,
      route_patterns: route_patterns,
      pattern_ids_by_stop: pattern_ids_by_stop
    })
  end

  defp miles_to_meters(miles), do: round(miles * 1_609.344)

  # The V3 API does not actually calculate distance,
  # and it just pretends latitude degrees and longitude degrees are equally sized.
  # See https://github.com/mbta/api/blob/1671ba02d4669827fb2a58966d8c3ab39c939b0e/apps/api_web/lib/api_web/controllers/stop_controller.ex#L27-L31.
  # For now, this is fine.
  defp miles_to_degrees(miles), do: miles * 0.02
end

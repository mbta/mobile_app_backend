defmodule MobileAppBackendWeb.NearbyController do
  use MobileAppBackendWeb, :controller

  @type stop_map() :: MBTAV3API.Stop.stop_map()

  def show(conn, params) do
    params = Map.merge(%{"radius" => "1.0"}, params)
    latitude = String.to_float(Map.fetch!(params, "latitude"))
    longitude = String.to_float(Map.fetch!(params, "longitude"))
    radius = String.to_float(Map.fetch!(params, "radius"))

    now =
      if now = Map.get(params, "now") do
        Util.parse_datetime!(now)
      else
        DateTime.now!("America/New_York")
      end

    stops =
      fetch_nearby_stops(latitude, longitude, radius)
      |> MBTAV3API.Stop.include_missing_siblings()

    {route_patterns, pattern_ids_by_stop} = fetch_route_patterns(stops)

    alerts = fetch_alerts(stops, now)

    json(conn, %{
      stops:
        stops
        |> Map.values()
        |> Enum.filter(&Map.has_key?(pattern_ids_by_stop, &1.id))
        |> Enum.sort(
          &(distance_in_degrees(&1.latitude || 0, &1.longitude || 0, latitude, longitude) <=
              distance_in_degrees(&2.latitude || 0, &2.longitude || 0, latitude, longitude))
        ),
      route_patterns: route_patterns,
      pattern_ids_by_stop: pattern_ids_by_stop,
      alerts: alerts
    })
  end

  @spec fetch_nearby_stops(
          latitude :: float(),
          longitude :: float(),
          radius :: float()
        ) :: stop_map()
  defp fetch_nearby_stops(latitude, longitude, radius) do
    degree_radius = miles_to_degrees(radius)

    {:ok, cr_stops} =
      MBTAV3API.Stop.get_all(
        filter: [
          latitude: latitude,
          longitude: longitude,
          location_type: [:stop, :station],
          radius: degree_radius,
          route_type: :commuter_rail
        ],
        include: [parent_station: :child_stops],
        sort: {:distance, :asc}
      )

    {:ok, other_stops} =
      MBTAV3API.Stop.get_all(
        filter: [
          latitude: latitude,
          longitude: longitude,
          location_type: [:stop, :station],
          radius: degree_radius / 2,
          route_type: [:light_rail, :heavy_rail, :bus, :ferry]
        ],
        include: {:parent_station, :child_stops},
        sort: {:distance, :asc}
      )

    Map.new(cr_stops ++ other_stops, &{&1.id, &1})
  end

  @spec fetch_route_patterns(stops :: stop_map()) ::
          {%{(route_pattern_id :: String.t()) => route_pattern :: map()},
           %{(stop_id :: String.t()) => route_patterns :: [String.t()]}}
  defp fetch_route_patterns(stops) do
    {:ok, route_patterns} =
      MBTAV3API.RoutePattern.get_all(
        filter: [stop: Enum.join(Map.keys(stops), ",")],
        include: [:route, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop = MBTAV3API.RoutePattern.get_pattern_ids_by_stop(route_patterns, stops)

    route_patterns =
      Map.new(
        route_patterns,
        &{&1.id,
         %{
           &1
           | representative_trip: %{headsign: &1.representative_trip.headsign}
         }}
      )

    {route_patterns, pattern_ids_by_stop}
  end

  def fetch_alerts(stops, now) do
    {:ok, alerts} = MBTAV3API.Alert.get_all(filter: [stop: Map.keys(stops)])

    Enum.filter(alerts, fn alert ->
      MBTAV3API.Alert.active?(alert, now) and
        alert.effect in [
          :detour,
          :shuttle,
          :station_closure,
          :stop_closure,
          :suspension
        ]
    end)
  end

  @spec distance_in_degrees(
          lat1 :: float(),
          lon1 :: float(),
          lat2 :: float(),
          lon2 :: float()
        ) :: float()
  defp distance_in_degrees(lat1, lon1, lat2, lon2),
    do: abs(:math.sqrt((lat2 - lat1) ** 2 + (lon2 - lon1) ** 2))

  # The V3 API does not actually calculate distance,
  # and it just pretends latitude degrees and longitude degrees are equally sized.
  # See https://github.com/mbta/api/blob/1671ba02d4669827fb2a58966d8c3ab39c939b0e/apps/api_web/lib/api_web/controllers/stop_controller.ex#L27-L31.
  # For now, this is fine.
  defp miles_to_degrees(miles), do: miles * 0.01664
end

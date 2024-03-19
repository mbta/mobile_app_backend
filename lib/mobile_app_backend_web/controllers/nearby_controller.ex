defmodule MobileAppBackendWeb.NearbyController do
  alias MBTAV3API.{JsonApi, Repository}
  use MobileAppBackendWeb, :controller

  def show(conn, params) do
    params = Map.merge(%{"radius" => "1.0"}, params)
    latitude = String.to_float(Map.fetch!(params, "latitude"))
    longitude = String.to_float(Map.fetch!(params, "longitude"))
    radius = String.to_float(Map.fetch!(params, "radius"))

    {stops, included_stops} = fetch_nearby_stops(latitude, longitude, radius)
    stops = MBTAV3API.Stop.include_missing_siblings(stops, included_stops)

    parent_stops =
      Map.filter(included_stops, fn {_, stop} ->
        not is_nil(stop.child_stop_ids) and length(stop.child_stop_ids) > 0
      end)

    %{
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    } = fetch_route_patterns(stops)

    json(conn, %{
      pattern_ids_by_stop: pattern_ids_by_stop,
      parent_stops: parent_stops,
      routes: routes,
      route_patterns: route_patterns,
      stops:
        stops
        |> Map.values()
        |> Enum.filter(&Map.has_key?(pattern_ids_by_stop, &1.id))
        |> Enum.sort_by(
          &distance_in_degrees(&1.latitude || 0, &1.longitude || 0, latitude, longitude)
        ),
      trips: trips
    })
  end

  @spec fetch_nearby_stops(
          latitude :: float(),
          longitude :: float(),
          radius :: float()
        ) :: {primary :: JsonApi.Object.stop_map(), included :: JsonApi.Object.stop_map()}
  defp fetch_nearby_stops(latitude, longitude, radius) do
    degree_radius = miles_to_degrees(radius)

    {:ok, %{data: cr_stops, included: %{stops: cr_included_stops}}} =
      Repository.stops(
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

    {:ok, %{data: other_stops, included: %{stops: other_included_stops}}} =
      Repository.stops(
        filter: [
          latitude: latitude,
          longitude: longitude,
          location_type: [:stop, :station],
          radius: degree_radius / 2,
          route_type: [:light_rail, :heavy_rail, :bus, :ferry]
        ],
        include: [parent_station: :child_stops],
        sort: {:distance, :asc}
      )

    {Map.new(cr_stops ++ other_stops, &{&1.id, &1}),
     Map.merge(cr_included_stops, other_included_stops)}
  end

  @spec fetch_route_patterns(JsonApi.Object.stop_map()) :: %{
          routes: JsonApi.Object.route_map(),
          route_patterns: JsonApi.Object.route_pattern_map(),
          trips: JsonApi.Object.trip_map(),
          pattern_ids_by_stop: %{(stop_id :: String.t()) => route_pattern_ids :: [String.t()]}
        }
  defp fetch_route_patterns(stops) do
    {:ok, %{data: route_patterns, included: %{routes: routes, trips: trips}}} =
      Repository.route_patterns(
        filter: [stop: Enum.join(Map.keys(stops), ",")],
        include: [:route, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop =
      MBTAV3API.RoutePattern.get_pattern_ids_by_stop(
        route_patterns,
        trips,
        MapSet.new(Map.keys(stops))
      )

    trips =
      Map.new(trips, fn {trip_id, trip} -> {trip_id, %MBTAV3API.Trip{trip | stop_ids: nil}} end)

    route_patterns = Map.new(route_patterns, &{&1.id, &1})

    %{
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    }
  end

  @spec distance_in_degrees(float(), float(), float(), float()) :: float()
  defp distance_in_degrees(lat1, lon1, lat2, lon2) do
    abs(:math.sqrt((lat2 - lat1) ** 2 + (lon2 - lon1) ** 2))
  end

  # The V3 API does not actually calculate distance,
  # and it just pretends latitude degrees and longitude degrees are equally sized.
  # See https://github.com/mbta/api/blob/1671ba02d4669827fb2a58966d8c3ab39c939b0e/apps/api_web/lib/api_web/controllers/stop_controller.ex#L27-L31.
  # For now, this is fine.
  defp miles_to_degrees(miles), do: miles * 0.01664
end

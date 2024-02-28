defmodule MobileAppBackendWeb.NearbyController do
  alias MBTAV3API.{JsonApi, Repository}
  use MobileAppBackendWeb, :controller

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

    stops = fetch_nearby_stops(latitude, longitude, radius)

    %{
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    } = fetch_route_patterns(stops)

    alerts = fetch_alerts(stops, now)

    stop_children =
      Enum.group_by(
        stops,
        fn {_stop_id, stop} -> stop.parent_station_id end,
        fn {stop_id, _} -> stop_id end
      )

    stops =
      Map.filter(stops, fn {stop_id, _} ->
        with_children = [stop_id | Map.get(stop_children, stop_id, [])]
        Enum.any?(with_children, &Map.has_key?(pattern_ids_by_stop, &1))
      end)

    json(conn, %{
      pattern_ids_by_stop: pattern_ids_by_stop,
      routes: routes,
      route_patterns: route_patterns,
      stops: stops,
      trips: trips,
      alerts: alerts
    })
  end

  @spec fetch_nearby_stops(
          latitude :: float(),
          longitude :: float(),
          radius :: float()
        ) :: JsonApi.Object.stop_map()
  defp fetch_nearby_stops(latitude, longitude, radius) do
    degree_radius = miles_to_degrees(radius)

    {:ok, %{stops: cr_stops}} =
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

    {:ok, %{stops: other_stops}} =
      Repository.stops(
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

    Map.merge(cr_stops, other_stops)
    |> Map.filter(fn {_id, stop} -> stop.location_type in [:stop, :station] end)
  end

  @spec fetch_route_patterns(JsonApi.Object.stop_map()) :: %{
          routes: JsonApi.Object.route_map(),
          route_patterns: JsonApi.Object.route_pattern_map(),
          trips: JsonApi.Object.trip_map(),
          pattern_ids_by_stop: %{(stop_id :: String.t()) => route_pattern_ids :: [String.t()]}
        }
  defp fetch_route_patterns(stops) do
    {:ok, %{routes: routes, route_patterns: route_patterns, trips: trips}} =
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

    %{
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    }
  end

  def fetch_alerts(stops, now) do
    {:ok, %{alerts: alerts}} = Repository.alerts(filter: [stop: Map.keys(stops)])

    alerts
    |> Map.values()
    |> Enum.filter(fn alert ->
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

  # The V3 API does not actually calculate distance,
  # and it just pretends latitude degrees and longitude degrees are equally sized.
  # See https://github.com/mbta/api/blob/1671ba02d4669827fb2a58966d8c3ab39c939b0e/apps/api_web/lib/api_web/controllers/stop_controller.ex#L27-L31.
  # For now, this is fine.
  defp miles_to_degrees(miles), do: miles * 0.01664
end

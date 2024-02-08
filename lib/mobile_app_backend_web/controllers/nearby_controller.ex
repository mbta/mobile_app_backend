defmodule MobileAppBackendWeb.NearbyController do
  use MobileAppBackendWeb, :controller

  def show(conn, params) do
    params = Map.merge(%{"radius" => "1.0"}, params)
    latitude = String.to_float(Map.fetch!(params, "latitude"))
    longitude = String.to_float(Map.fetch!(params, "longitude"))
    radius = String.to_float(Map.fetch!(params, "radius"))

    degree_radius = miles_to_degrees(radius)

    {:ok, cr_stops} =
      MBTAV3API.Stop.get_all(
        filter: [
          latitude: latitude,
          longitude: longitude,
          location_type: [0, 1],
          radius: degree_radius,
          route_type: "2"
        ],
        include: {:parent_station, :child_stops},
        sort: {:distance, :asc}
      )

    {:ok, other_stops} =
      MBTAV3API.Stop.get_all(
        filter: [
          latitude: latitude,
          longitude: longitude,
          location_type: [0, 1],
          radius: degree_radius / 2,
          route_type: "0,1,3,4"
        ],
        include: {:parent_station, :child_stops},
        sort: {:distance, :asc}
      )

    stops = (cr_stops ++ other_stops) |> Enum.uniq_by(& &1.id)
    stop_ids = MapSet.new(stops, & &1.id)

    missing_sibling_stop_ids =
      stops
      |> Enum.filter(&(&1.parent_station != nil))
      |> Enum.flat_map(& &1.parent_station.child_stops)
      |> Enum.filter(
        &case &1 do
          %MBTAV3API.Stop{} -> Enum.member?([0, 1], &1.location_type)
          _ -> false
        end
      )
      |> Enum.map(& &1.id)
      |> Enum.uniq()
      |> Enum.filter(&(!Enum.member?(stop_ids, &1)))

    []

    missing_sibling_stops =
      if Enum.empty?(missing_sibling_stop_ids) do
        []
      else
        {:ok, missing_sibling_stops} =
          MBTAV3API.Stop.get_all(
            filter: [
              location_type: [0, 1],
              id: missing_sibling_stop_ids |> Enum.join(",")
            ],
            include: :parent_station
          )

        missing_sibling_stops
      end

    stops =
      (stops ++ missing_sibling_stops)
      |> Enum.map(
        &%MBTAV3API.Stop{
          &1
          | child_stops: nil,
            parent_station:
              if(&1.parent_station == nil,
                do: nil,
                else: %MBTAV3API.Stop{&1.parent_station | child_stops: nil}
              )
        }
      )
      |> Enum.sort(
        &(distance_in_degrees(&1.latitude || 0, &1.longitude || 0, latitude, longitude) <=
            distance_in_degrees(&2.latitude || 0, &2.longitude || 0, latitude, longitude))
      )

    stop_ids = MapSet.union(stop_ids, MapSet.new(missing_sibling_stop_ids))

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

    stops = stops |> Enum.filter(&Map.has_key?(pattern_ids_by_stop, &1.id))

    json(conn, %{
      stops: stops,
      route_patterns: route_patterns,
      pattern_ids_by_stop: pattern_ids_by_stop
    })
  end

  defp distance_in_degrees(lat1, lon1, lat2, lon2),
    do: abs(:math.sqrt((lat2 - lat1) ** 2 + (lon2 - lon1) ** 2))

  # The V3 API does not actually calculate distance,
  # and it just pretends latitude degrees and longitude degrees are equally sized.
  # See https://github.com/mbta/api/blob/1671ba02d4669827fb2a58966d8c3ab39c939b0e/apps/api_web/lib/api_web/controllers/stop_controller.ex#L27-L31.
  # For now, this is fine.
  defp miles_to_degrees(miles), do: miles * 0.01664
end

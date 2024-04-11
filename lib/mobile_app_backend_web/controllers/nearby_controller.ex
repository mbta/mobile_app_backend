defmodule MobileAppBackendWeb.NearbyController do
  alias MBTAV3API.{JsonApi, Repository}
  use MobileAppBackendWeb, :controller

  def show(conn, params) do
    params = Map.merge(%{"radius" => "1.0"}, params)
    latitude = String.to_float(Map.fetch!(params, "latitude"))
    longitude = String.to_float(Map.fetch!(params, "longitude"))
    radius = String.to_float(Map.fetch!(params, "radius"))

    stops = fetch_nearby_stops(latitude, longitude, radius)

    json(conn, %{
      stop_ids:
        stops
        |> Map.values()
        |> Enum.sort_by(
          &distance_in_degrees(&1.latitude || 0, &1.longitude || 0, latitude, longitude)
        )
        |> Enum.map(& &1.id)
    })
  end

  @spec fetch_nearby_stops(
          latitude :: float(),
          longitude :: float(),
          radius :: float()
        ) :: primary :: JsonApi.Object.stop_map()
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

    cr_stop_map =
      :maps.filter(
        fn _, v -> v.vehicle_type == :commuter_rail end,
        MBTAV3API.Stop.include_missing_siblings(
          Map.new(cr_stops, &{&1.id, &1}),
          cr_included_stops
        )
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

    other_stop_map =
      MBTAV3API.Stop.include_missing_siblings(
        Map.new(other_stops, &{&1.id, &1}),
        other_included_stops
      )

    Map.merge(cr_stop_map, other_stop_map)
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

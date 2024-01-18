defmodule MobileAppBackendWeb.NearbyController do
  use MobileAppBackendWeb, :controller

  def show(conn, params) do
    {:ok, stops} =
      MBTAV3API.Stop.get_all(
        "filter[latitude]": String.to_float(params["latitude"]),
        "filter[longitude]": String.to_float(params["longitude"]),
        "filter[location_type]": "0,1",
        "filter[radius]": miles_to_degrees(0.5),
        include: :parent_station,
        sort: :distance
      )

    stops =
      stops
      |> Enum.map(&MBTAV3API.Stop.parent/1)
      |> Enum.uniq()

    # Getting all route patterns at any stop loses the information of which stop is in which route patterns.
    {stop_patterns, route_patterns} =
      stops
      |> Task.async_stream(fn stop ->
        {:ok, route_patterns} =
          MBTAV3API.RoutePattern.get_all(
            "filter[stop]": stop.id,
            include: :route,
            sort: :sort_order
          )

        {stop.id, route_patterns}
      end)
      |> Enum.reduce({%{}, %{}}, fn {:ok, {stop_id, route_patterns}},
                                    {stop_patterns, route_pattern_map} ->
        {Map.put(stop_patterns, stop_id, Enum.map(route_patterns, & &1.id)),
         Map.merge(route_pattern_map, Map.new(route_patterns, &{&1.id, &1}))}
      end)

    json(conn, %{stops: stops, stop_patterns: stop_patterns, route_patterns: route_patterns})
  end

  # The V3 API does not actually calculate distance,
  # and it just pretends latitude degrees and longitude degrees are equally sized.
  # For now, this is fine.
  defp miles_to_degrees(miles), do: miles * 0.02
end

defmodule MobileAppBackendWeb.ShapesController do
  alias MobileAppBackend.MapFriendlyRouteShape
  alias MobileAppBackend.RouteSegment
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Repository
  alias MBTAV3API.RoutePattern
  use MobileAppBackendWeb, :controller

  def rail(conn, _params) do
    %{routes: routes, route_patterns: route_patterns, shapes: shapes, trips: trips} =
      fetch_all_rail_route_data()

    json(conn, %{routes: routes, route_patterns: route_patterns, shapes: shapes, trips: trips})
  end

  @spec fetch_all_rail_route_data() :: %{
          routes: [MBTAV3API.Route.t()],
          route_patterns: JsonApi.Object.route_pattern_map(),
          shapes: JsonApi.Object.shape_map(),
          trips: JsonApi.Object.trip_map()
        }
  defp fetch_all_rail_route_data do
    {:ok,
     %{data: routes, included: %{route_patterns: route_patterns, shapes: shapes, trips: trips}}} =
      Repository.routes(
        filter: [
          type: [:light_rail, :heavy_rail, :commuter_rail]
        ],
        include: [route_patterns: [representative_trip: [:shape, :stops]]]
      )

    %{routes: routes, route_patterns: route_patterns, shapes: shapes, trips: trips}
  end

  def rail_for_map(conn, _params) do
    %{
      route_patterns: route_patterns,
      trips_by_id: trips_by_id,
      shapes_by_id: shapes_by_id,
      stops_by_id: stops_by_id
    } =
      fetch_rail_data_for_map()

    route_segments =
      RouteSegment.non_overlapping_segments(
        route_patterns,
        stops_by_id,
        trips_by_id
      )

    map_friendly_route_shapes =
      MapFriendlyRouteShape.from_segments(
        route_segments,
        Map.new(route_patterns, &{&1.id, &1}),
        trips_by_id,
        shapes_by_id
      )

    json(conn, %{
      map_friendly_route_shapes: map_friendly_route_shapes
    })
  end

  # Get the rail patterns & shapes most relevant for display on a map in a single direction
  defp fetch_rail_data_for_map do
    {:ok, %{data: _routes, included: %{route_patterns: route_patterns_by_id}}} =
      Repository.routes(
        filter: [
          type: [:light_rail, :heavy_rail, :commuter_rail],
          direction_id: 0
        ],
        include: [
          route_patterns: [representative_trip: [:shape, :stops, [stops: :parent_station]]]
        ]
      )

    map_friendly_patterns =
      RoutePattern.most_canonical_or_typical_per_route(Map.values(route_patterns_by_id))

    trip_ids =
      map_friendly_patterns
      |> Enum.reject(&is_nil(&1.representative_trip_id))
      |> Enum.map(& &1.representative_trip_id)

    {:ok, %{data: trips, included: %{shapes: shapes_by_id, stops: stops_by_id}}} =
      Repository.trips(
        filter: [
          id: trip_ids
        ],
        include: [:shape, :stops]
      )

    %{
      route_patterns: map_friendly_patterns,
      trips_by_id: Map.new(trips, &{&1.id, &1}),
      shapes_by_id: shapes_by_id,
      stops_by_id: stops_by_id
    }
  end
end

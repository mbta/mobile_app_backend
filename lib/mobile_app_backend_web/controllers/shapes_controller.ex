defmodule MobileAppBackendWeb.ShapesController do
  alias MBTAV3API.Repository
  alias MBTAV3API.RoutePattern
  alias MobileAppBackend.MapFriendlyRouteShape
  alias MobileAppBackend.RouteSegment
  use MobileAppBackendWeb, :controller

  def rail(conn, params) do
    should_separate_overlapping_segments =
      Map.get(params, "separate_overlapping_segments", "false")

    routes_filter = [
      type: [:light_rail, :heavy_rail, :commuter_rail]
    ]

    json(conn, %{
      map_friendly_route_shapes: filtered_map_shapes(routes_filter, should_separate_overlapping_segments)
    })
  end

  def filtered_map_shapes(routes_filter, should_separate_overlapping_segments) do
    routes_filter
      |> fetch_shape_data_for_map()
      |> map_friendly_route_shapes(should_separate_overlapping_segments)
  end

  defp map_friendly_route_shapes(
         %{
           route_patterns: route_patterns,
           routes_by_id: routes_by_id,
           trips_by_id: trips_by_id,
           shapes_by_id: shapes_by_id,
           stops_by_id: stops_by_id
         },
         should_separate_overlapping_segments
       ) do
    segment_fn =
      case should_separate_overlapping_segments do
        "true" -> &RouteSegment.non_overlapping_segments/4
        _ -> &RouteSegment.segment_per_pattern/4
      end

    route_segments =
      segment_fn.(
        route_patterns,
        stops_by_id,
        trips_by_id,
        %{
          "Green-B" => "Green",
          "Green-C" => "Green",
          "Green-D" => "Green",
          "Green-E" => "Green",
          "CR-Worcester" => "CR-SW",
          "CR-Needham" => "CR-SW",
          "CR-Fairmount" => "CR-SW",
          "CR-Franklin" => "CR-SW",
          "CR-Providence" => "CR-SW",
          "CR-Middleborough" => "CR-SE",
          "CR-Kingston" => "CR-SE",
          "CR-Greenbush" => "CR-SE"
        }
      )

    route_segments
    |> MapFriendlyRouteShape.from_segments(
      Map.new(route_patterns, &{&1.id, &1}),
      trips_by_id,
      shapes_by_id
    )
    |> Enum.group_by(& &1.source_route_id)
    |> Enum.map(fn {route_id, route_shapes} ->
      %{route_id: route_id, route_shapes: route_shapes}
    end)
    |> Enum.sort_by(&Map.fetch!(routes_by_id, &1.route_id).sort_order)
  end

  # Get the rail patterns & shapes most relevant for display on a map in a single direction
  defp fetch_shape_data_for_map(routes_filter) do
    {:ok, %{data: routes, included: %{route_patterns: route_patterns_by_id}}} =
      Repository.routes(
        filter: routes_filter,
        include: [:route_patterns]
      )

    map_friendly_patterns =
      route_patterns_by_id
      |> Map.values()
      |> Enum.filter(&(&1.direction_id == 0))
      |> RoutePattern.most_canonical_or_typical_per_route()

    trip_ids =
      map_friendly_patterns
      |> Enum.reject(&is_nil(&1.representative_trip_id))
      |> Enum.map(& &1.representative_trip_id)

    {:ok, %{data: trips, included: %{shapes: shapes_by_id, stops: stops_by_id}}} =
      Repository.trips(
        filter: [
          id: trip_ids
        ],
        include: [:shape, [stops: :parent_station]]
      )

    %{
      route_patterns: map_friendly_patterns,
      routes_by_id: Map.new(routes, &{&1.id, &1}),
      trips_by_id: Map.new(trips, &{&1.id, &1}),
      shapes_by_id: shapes_by_id,
      stops_by_id: stops_by_id
    }
  end
end

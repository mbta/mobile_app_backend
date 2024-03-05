defmodule MobileAppBackendWeb.ShapesController do
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Repository
  use MobileAppBackendWeb, :controller

  def rail(conn, _params) do
    %{routes: routes, route_patterns: route_patterns, shapes: shapes, trips: trips} =
      fetch_rail_routes()

    json(conn, %{routes: routes, route_patterns: route_patterns, shapes: shapes, trips: trips})
  end

  @spec fetch_rail_routes() :: %{
          routes: [MBTAV3API.Route.t()],
          route_patterns: JsonApi.Object.route_pattern_map(),
          shapes: JsonApi.Object.shape_map(),
          trips: JsonApi.Object.trip_map()
        }
  defp fetch_rail_routes do
    {:ok,
     %{data: routes, included: %{route_patterns: route_patterns, shapes: shapes, trips: trips}}} =
      Repository.routes(
        filter: [
          type: [:light_rail, :heavy_rail, :commuter_rail]
        ],
        include: [route_patterns: [representative_trip: :shape]]
      )

    %{routes: routes, route_patterns: route_patterns, shapes: shapes, trips: trips}
  end
end

defmodule MobileAppBackendWeb.ShapesController do
  # alias MBTAV3API.JsonApi
  use MobileAppBackendWeb, :controller

  @type stop_map() :: MBTAV3API.Stop.stop_map()

  def rail(conn, _params) do
    routes = fetch_rail_routes()

    json(conn, %{
      routes: routes
    })
  end

  @spec fetch_rail_routes() :: [MBTAV3API.Route.t()]
  defp fetch_rail_routes do
    {:ok, routes} =
      MBTAV3API.Route.get_all(
        filter: [
          type: [:light_rail, :heavy_rail, :commuter_rail]
        ],
        include: [route_patterns: [representative_trip: :shape]]
      )

    routes
  end
end

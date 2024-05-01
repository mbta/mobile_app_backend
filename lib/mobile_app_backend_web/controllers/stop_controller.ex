defmodule MobileAppBackendWeb.StopController do
  alias MBTAV3API.Repository
  alias MobileAppBackendWeb.ShapesController
  use MobileAppBackendWeb, :controller

  def map(conn, %{"stop_id" => stop_id}) do
    routes_filter = [stop: [stop_id]]

    json(conn, %{
      map_friendly_route_shapes: ShapesController.filtered_map_shapes(routes_filter),
      child_stops: fetch_all_child_stops(stop_id)
    })
  end

  defp fetch_all_child_stops(stop_id) do
    {:ok, %{included: %{stops: child_stops}}} =
      Repository.stops(
        filter: [id: stop_id],
        include: [:child_stops]
      )

    child_stops
  end
end

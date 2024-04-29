defmodule MobileAppBackendWeb.StopController do
  alias MBTAV3API.Repository
  alias MobileAppBackendWeb.ShapesController
  use MobileAppBackendWeb, :controller

  def map(conn, %{"stop_id" => stop_id} = params) do
    should_separate_overlapping_segments =
      Map.get(params, "separate_overlapping_segments", "false")

    routes_filter = [stop: [stop_id]]

    json(conn, %{
      map_friendly_route_shapes:
        ShapesController.filtered_map_shapes(routes_filter, should_separate_overlapping_segments),
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

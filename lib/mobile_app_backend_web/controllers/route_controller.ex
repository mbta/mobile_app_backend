defmodule MobileAppBackendWeb.RouteController do
  alias MBTAV3API.Repository
  use MobileAppBackendWeb, :controller

  def stops(conn, %{"route_id" => route_id, "direction_id" => direction_id}) do
    {:ok, %{data: stops}} =
      Repository.stops(
        filter: [route: route_id, direction_id: direction_id],
        fields: [stop: [:id]]
      )

    json(conn, %{stop_ids: stops |> Enum.map(fn stop -> stop.id end)})
  end
end

defmodule MobileAppBackendWeb.RouteController do
  use MobileAppBackendWeb, :controller

  alias MBTAV3API.Repository
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.RouteBranching

  def stops(conn, %{"route_id" => route_id, "direction_id" => direction_id}) do
    {:ok, %{data: stops}} =
      Repository.stops(
        filter: [route: route_id, direction_id: direction_id],
        fields: [stop: [:id]]
      )

    json(conn, %{stop_ids: stops |> Enum.map(fn stop -> stop.id end)})
  end

  def stop_graph(conn, %{"route_id" => route_id, "direction_id" => direction_id}) do
    direction_id = String.to_integer(direction_id)

    {:ok, %{data: stops}} =
      Repository.stops(
        filter: [route: route_id, direction_id: direction_id],
        fields: [stop: [:id]]
      )

    stop_ids = stops |> Enum.map(fn stop -> stop.id end)
    global_data = GlobalDataCache.get_data()

    {_stop_graph, _segment_graph, branches} =
      RouteBranching.calculate(route_id, direction_id, stop_ids, global_data)

    json(conn, branches)
  end
end

defmodule MobileAppBackendWeb.StopController do
  use MobileAppBackendWeb, :controller

  plug(:put_view, MobileAppBackendWeb.StopView)

  plug JSONAPI.QueryParser, view: MobileAppBackendWeb.StopView

  def show(conn, %{"id" => stop_id}) do
    stop_info = Stops.Repo.get!(stop_id)

    routes =
      Routes.Repo.by_stop_with_route_pattern(stop_id)
      |> Enum.map(fn {route, route_patterns} ->
        Map.put(route, :route_patterns, route_patterns)
      end)

    stop_info = Map.put(stop_info, :routes, routes)

    render(conn, "show.json", %{data: stop_info})
  end
end

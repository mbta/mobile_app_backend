defmodule MobileAppBackendWeb.RouteController do
  use MobileAppBackendWeb, :controller

  alias V3Api.Routes

  def by_stop(conn, %{"stop_id" => stop_id} = _params) do
    route = Routes.by_stop(stop_id)
    json(conn, route)
  end
end

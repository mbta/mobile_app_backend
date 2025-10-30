defmodule MobileAppBackendWeb.AlertsController do
  use MobileAppBackendWeb, :controller
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Store

  def show(conn, _params) do
    alerts = Store.Alerts.fetch([])
    json(conn, JsonApi.Object.to_full_map(alerts))
  end
end

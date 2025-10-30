defmodule MobileAppBackendWeb.AlertsControllerTest do
  use MobileAppBackendWeb.ConnCase, async: false
  import MobileAppBackend.Factory
  alias MBTAV3API.JsonApi

  test "contains list of alerts", %{conn: conn} do
    start_link_supervised!(MBTAV3API.Store.Alerts)
    alerts = build_list(4, :alert)
    data = JsonApi.Object.to_full_map(alerts)
    MBTAV3API.Store.Alerts.process_reset(alerts, [])
    conn = get(conn, ~p"/api/alerts")
    assert json_response(conn, :ok) == Jason.decode!(Jason.encode!(data))
  end
end

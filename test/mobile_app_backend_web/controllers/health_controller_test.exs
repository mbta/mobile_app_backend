defmodule MobileAppBackendWeb.HealthControllerTest do
  use MobileAppBackendWeb.ConnCase, async: true

  describe "GET /_health" do
    test "returns 200 Ok when healthy", %{conn: conn} do
      conn = put_private(conn, :health_check_module, __MODULE__.Healthy)
      assert %{status: 200, resp_body: "Ok"} = get(conn, "/_health")
    end

    @tag capture_log: true
    test "returns 503 Service Unavailable when not healthy", %{conn: conn} do
      conn = put_private(conn, :health_check_module, __MODULE__.Unhealthy)
      assert %{status: 503, resp_body: "Service Unavailable"} = get(conn, "/_health")
    end
  end

  defmodule Healthy do
    def healthy?, do: true
  end

  defmodule Unhealthy do
    def healthy?, do: false
  end
end

defmodule MobileAppBackendWeb.HealthControllerTest do
  use MobileAppBackendWeb.ConnCase, async: true

  describe "GET /_health" do
    test "returns 200 Ok", %{conn: conn} do
      assert %{status: 200, resp_body: "Ok"} = get(conn, "/_health")
    end
  end
end

defmodule MobileAppBackendWeb.ClientControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Test.Support.Helpers
  import Mox
  alias MobileAppBackend.MapboxTokenRotator

  describe "GET /api/protected/config" do
    setup do
      verify_on_exit!()

      reassign_env(:mobile_app_backend, MobileAppBackend.ClientConfig,
        mapbox_public_token: "fake_mapbox_token"
      )

      MapboxTokenRotator |> Process.whereis() |> Process.exit(:refresh_config)

      :ok
    end

    test "returns config", %{conn: conn} do
      conn = get(conn, "/api/protected/config")
      %{"mapbox_public_token" => "fake_mapbox_token"} = json_response(conn, 200)
    end
  end
end

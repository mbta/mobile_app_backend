defmodule MobileAppBackendWeb.ClientControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Test.Support.Helpers
  import Mox

  describe "GET /api/protected/config" do
    setup do
      verify_on_exit!()

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.MapboxTokenRotator,
        MapboxTokenRotatorMock
      )

      :ok
    end

    test "returns config", %{conn: conn} do
      MapboxTokenRotatorMock
      |> expect(:get_public_token, fn -> "fake_mapbox_token" end)

      conn = get(conn, "/api/protected/config")
      %{"mapbox_public_token" => "fake_mapbox_token"} = json_response(conn, 200)
    end
  end
end

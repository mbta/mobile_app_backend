defmodule MobileAppBackendWeb.ClientControllerTest do
  use HttpStub.Case
  use MobileAppBackendWeb.ConnCase
  import Test.Support.Helpers
  import Mox

  describe "GET /api/protected/config" do
    setup do
      verify_on_exit!()

      reassign_env(:mobile_app_backend, MobileAppBackend.ClientConfig,
        mapbox_public_token: "fake_mapbox_token"
      )

      reassign_env(:mobile_app_backend, MobileAppBackend.AppCheck.JwksApi, JwksApiMock)

      # Correspond to valid claims in MobileAppBackend.AppCheck.MockGuardian
      reassign_env(:mobile_app_backend, MobileAppBackend.AppCheck,
        guardian_module: MobileAppBackend.AppCheck.MockGuardian,
        issuer: "valid_issuer",
        project: "valid_project",
        subjects: ["valid_subject", "other_valid_subject"]
      )

      reassign_env(:mobile_app_backend, :peek_headers, fn _token ->
        %JOSE.JWS{fields: %{"kid" => "target_kid", "typ" => "JWT"}}
      end)

      JwksApiMock
      |> expect(:read_jwks, 1, fn ->
        {:ok, [%{"kid" => "target_kid"}]}
      end)

      :ok
    end

    @tag :firebase_valid_token
    test "when valid token, returns config", %{conn: conn} do
      conn = get(conn, "/api/protected/config")
      %{"mapbox_public_token" => "fake_mapbox_token"} = json_response(conn, 200)
    end

    @tag :firebase_invalid_token
    @tag :capture_log
    test "when invalid token, returns 401 error", %{conn: conn} do
      conn = get(conn, "/api/protected/config")
      "invalid_token" = json_response(conn, 401)
    end
  end
end

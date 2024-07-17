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

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.AppCheck.Token,
        MobileAppBackend.AppCheck.TokenMock
      )

      # Correspond to valid claims in MobileAppBackend.AppCheck.TokenMock
      reassign_env(:mobile_app_backend, MobileAppBackend.AppCheck,
        issuer: "valid_issuer",
        project: "valid_project",
        subjects: ["valid_subject", "other_valid_subject"]
      )

      JwksApiMock
      |> expect(:read_jwks, 1, fn ->
        {:ok,
         [
           %{
             "kty" => "RSA",
             "use" => "sig",
             "alg" => "RS256",
             "kid" => "target_kid",
             "n" => "n_value",
             "e" => "e_value"
           }
         ]}
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

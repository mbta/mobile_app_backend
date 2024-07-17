defmodule MobileAppBackendWeb.Plugs.AppCheckTest do
  use MobileAppBackendWeb.ConnCase
  alias MobileAppBackendWeb.Plugs.AppCheck
  import Mox
  import Test.Support.Helpers

  describe "init/1" do
    test "passes options through unchanged" do
      assert AppCheck.init([]) == []
    end
  end

  describe "call/2" do
    setup do
      verify_on_exit!()
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

      :ok
    end

    @tag :capture_log
    test "when no firebase token, halts with 401", %{conn: conn} do
      JwksApiMock
      |> expect(:read_jwks, 0, fn ->
        {:ok,
         [
           %{
             "kty" => "RSA",
             "use" => "sig",
             "alg" => "RS256",
             "kid" => "mismatched_kid",
             "n" => "n_value",
             "e" => "e_value"
           }
         ]}
      end)

      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_valid_token
    test "when valid token returns conn", %{conn: conn} do
      default_jwks_mock()
      assert conn == AppCheck.call(conn, [])
    end

    @tag :firebase_invalid_token
    @tag :capture_log
    test "when invalid token halts with 401", %{conn: conn} do
      default_jwks_mock()
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_invalid_issuer
    @tag :capture_log
    test "when invalid issuer halts with 401", %{conn: conn} do
      default_jwks_mock()
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_invalid_project
    @tag :capture_log
    test "when invalid project halts with 401", %{conn: conn} do
      default_jwks_mock()
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_invalid_subject
    @tag :capture_log
    test "when invalid subject halts with 401", %{conn: conn} do
      default_jwks_mock()
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_valid_token
    @tag :capture_log
    test "when matching JWK not found for token, halts with 401", %{conn: conn} do
      JwksApiMock
      |> expect(:read_jwks, 1, fn ->
        {:ok,
         [
           %{
             "kty" => "RSA",
             "use" => "sig",
             "alg" => "RS256",
             "kid" => "mismatched_kid",
             "n" => "n_value",
             "e" => "e_value"
           }
         ]}
      end)

      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_expired_token
    @tag :capture_log
    test "when token is expired, halts with 401", %{conn: conn} do
      default_jwks_mock()

      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    defp default_jwks_mock do
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
    end
  end
end

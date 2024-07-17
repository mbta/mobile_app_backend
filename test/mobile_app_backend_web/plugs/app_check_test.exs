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

  describe "call/2 no token" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MobileAppBackend.AppCheck.JwksApi, JwksApiMock)

      reassign_env(:mobile_app_backend, :peek_headers, fn _token ->
        %JOSE.JWS{fields: %{"kid" => "target_kid"}}
      end)

      JwksApiMock
      |> expect(:read_jwks, 0, fn ->
        {:ok, [%{"kid" => "target_kid"}]}
      end)

      :ok
    end

    test "when no token halts with 401 ", %{conn: conn} do
      JwksApiMock
      |> expect(:read_jwks, 0, fn ->
        {:ok, [%{"kid" => "target_kid"}]}
      end)

      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end
  end

  describe "call/2" do
    setup do
      verify_on_exit!()
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
    test "when valid token returns conn", %{conn: conn} do
      assert conn == AppCheck.call(conn, [])
    end

    @tag :firebase_valid_token
    @tag :capture_log

    test "when matching JWK not found for token, halts with 401", %{conn: conn} do
      reassign_env(:mobile_app_backend, :peek_headers, fn _token ->
        %JOSE.JWS{fields: %{"kid" => "not_found", "typ" => "JWT"}}
      end)

      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_invalid_token
    @tag :capture_log
    test "when invalid token halts with 401", %{conn: conn} do
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_invalid_issuer
    @tag :capture_log
    test "when invalid issuer halts with 401", %{conn: conn} do
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_invalid_project
    @tag :capture_log
    test "when invalid project halts with 401", %{conn: conn} do
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end

    @tag :firebase_invalid_subject
    @tag :capture_log
    test "when invalid subject halts with 401", %{conn: conn} do
      conn = AppCheck.call(conn, [])

      assert conn.status == 401
      assert conn.halted
    end
  end
end

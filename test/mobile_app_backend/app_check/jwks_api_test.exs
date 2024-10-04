defmodule MobileAppBackend.AppCheck.JwksApiTest do
  use ExUnit.Case, async: true

  alias MobileAppBackend.AppCheck.JwksApi
  import Mox

  setup :verify_on_exit!

  describe "read_jwks/0" do
    test "when request is successful, jwks" do
      expect(
        MobileAppBackend.HTTPMock,
        :get,
        fn _req, _opts ->
          {:ok, %{body: %{"keys" => [%{"kid" => "key_1"}]}}}
        end
      )

      assert {:ok, [%{"kid" => "key_1"}]} ==
               JwksApi.read_jwks()
    end

    test "when request is errors, returns error" do
      expect(
        MobileAppBackend.HTTPMock,
        :get,
        fn _req, _opts ->
          {:error, :some_error}
        end
      )

      assert {:error, :some_error} ==
               JwksApi.read_jwks()
    end

    test "when unexpected response, returns error" do
      expect(
        MobileAppBackend.HTTPMock,
        :get,
        fn _req, _opts ->
          {:ok, "unexpected"}
        end
      )

      assert {:error, {:ok, "unexpected"}} ==
               JwksApi.read_jwks()
    end
  end
end

defmodule MBTAV3APITest do
  use ExUnit.Case, async: true

  import Mox
  import Test.Support.Helpers
  alias MBTAV3API.JsonApi

  setup _ do
    reassign_env(:mobile_app_backend, :base_url, "")
    reassign_env(:mobile_app_backend, :api_key, "")
    :ok
  end

  setup :verify_on_exit!

  describe "get_json/1" do
    @tag :capture_log
    test "normal responses return a JsonApi struct" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/normal_response"}} ->
          {:ok, Req.Response.json(%{data: []})}
        end
      )

      response = MBTAV3API.get_json("/normal_response")
      assert %JsonApi{} = response
      refute response.data == %{}
    end

    @tag :capture_log
    test "encodes the URL" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/normal%20response"}} ->
          {:ok, Req.Response.json(%{data: []})}
        end
      )

      response = MBTAV3API.get_json("/normal response")
      assert %JsonApi{} = response
      refute response.data == %{}
    end

    @tag :capture_log
    test "missing endpoints return an error" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/missing"}} ->
          {:ok,
           Req.Response.new(status: 404)
           |> Req.Response.json(%{errors: [%{code: :not_found}]})}
        end
      )

      response = MBTAV3API.get_json("/missing")
      assert {:error, [%JsonApi.Error{code: "not_found"}]} = response
    end

    @tag :capture_log
    test "can't connect returns an error" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/cant_connect"}} ->
          {:error, %Mint.TransportError{reason: :nxdomain}}
        end
      )

      response = MBTAV3API.get_json("/cant_connect")
      assert {:error, %{reason: _}} = response
    end

    @tag :capture_log
    test "passes an API key if present" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{
             url: %URI{path: "/with_api_key"},
             headers: headers,
             options: %{params: [other: "value"]}
           } ->
          assert {"x-api-key", "test_key"} in headers
          {:ok, Req.Response.json(%{data: []})}
        end
      )

      %JsonApi{} = MBTAV3API.get_json("/with_api_key", [other: "value"], api_key: "test_key")
    end

    @tag :capture_log
    test "does not pass an API key if not set" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{
             url: %URI{path: "/without_api_key"},
             headers: headers
           } ->
          refute Enum.any?(headers, &(elem(&1, 0) == "x-api-key"))
          {:ok, Req.Response.json(%{data: []})}
        end
      )

      %JsonApi{} = MBTAV3API.get_json("/without_api_key", [], api_key: nil)
    end
  end
end

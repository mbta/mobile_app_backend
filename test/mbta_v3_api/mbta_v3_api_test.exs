defmodule MBTAV3APITest do
  use ExUnit.Case, async: true

  import Mox
  import Test.Support.Helpers
  alias MBTAV3API.JsonApi.Reference
  alias MBTAV3API.{JsonApi, ResponseCache}
  alias Test.Support.SSEStub

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
          assert {"x-api-key", ["test_key"]} in headers
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

  describe "get_json/1 caching" do
    setup do
      on_exit(fn -> ResponseCache.delete_all() end)
    end

    test "when no response in the cache, stores it after fetching" do
      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{url: %URI{path: "/normal_response"}} ->
          {:ok, Req.Response.json(%{data: [%{"type" => "prediction", "id" => "p_1"}]})}
        end
      )

      response = MBTAV3API.get_json("/normal_response")
      assert %JsonApi{} = response

      assert {_time, ^response} =
               ResponseCache.get!(ResponseCache.cache_key("/normal_response", %{}))
    end

    test "when response in the cache and new data, stores new data" do
      cache_key = ResponseCache.cache_key("/normal_response", %{})

      ResponseCache.put(
        cache_key,
        {"last_modified",
         %{
           data: [%{"type" => "prediction", "id" => "p_1"}]
         }}
      )

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{
             url: %URI{path: "/normal_response"},
             headers: headers
           } ->
          assert ["last_modified"] == Map.get(headers, "if-modified-since")

          {:ok,
           Req.Response.json(%{data: [%{"type" => "prediction", "id" => "p_2"}]})
           |> Req.Response.put_header("last-modified", "new_last_modified")}
        end
      )

      response = MBTAV3API.get_json("/normal_response")
      assert %JsonApi{data: [%Reference{type: "prediction", id: "p_2"}]} = response

      assert {"new_last_modified", ^response} =
               ResponseCache.get!(cache_key)
    end

    test "when response in the cache and 304, returns cached data" do
      cache_key = ResponseCache.cache_key("/normal_response", %{})

      old_data = %JsonApi{
        data: [%Reference{type: "prediction", id: "p_1"}]
      }

      ResponseCache.put(cache_key, {"last_modified", old_data})

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{
             url: %URI{path: "/normal_response"},
             headers: headers
           } ->
          assert ["last_modified"] == Map.get(headers, "if-modified-since")
          {:ok, Req.Response.new(%{status: 304})}
        end
      )

      assert ^old_data = MBTAV3API.get_json("/normal_response")

      assert {"last_modified", ^old_data} = ResponseCache.get!(cache_key)
    end

    test "when error, returns error" do
      cache_key = ResponseCache.cache_key("/normal_response", %{})

      old_data = %JsonApi{
        data: [%Reference{type: "prediction", id: "p_1"}]
      }

      ResponseCache.put(cache_key, {"last_modified", old_data})

      expect(
        MobileAppBackend.HTTPMock,
        :request,
        fn %Req.Request{
             url: %URI{path: "/normal_response"},
             headers: headers
           } ->
          assert ["last_modified"] == Map.get(headers, "if-modified-since")
          {:error, Req.Response.new(%{status: 500})}
        end
      )

      assert {:error, %Req.Response{status: 500}} = MBTAV3API.get_json("/normal_response")
    end
  end

  describe "start_stream/3" do
    @tag :capture_log
    test "streams" do
      {:ok, stream_instance} =
        MBTAV3API.start_stream("/ok", %{"a" => "b", "c" => "d"},
          base_url: "http://example.com",
          api_key: "efg",
          type: MBTAV3API.Stop
        )

      refute_receive _

      sse_stub = SSEStub.get_from_instance(stream_instance)

      assert SSEStub.get_args(sse_stub) == [
               url: "http://example.com/ok?a=b&c=d",
               headers: [{"x-api-key", "efg"}],
               idle_timeout: :timer.seconds(45)
             ]

      SSEStub.push_events(sse_stub, [%ServerSentEventStage.Event{event: "reset", data: "[]"}])

      assert_receive {:stream_data, %{}}
    end
  end

  describe "stream_args/3" do
    test "defaults to sending to self" do
      args =
        MBTAV3API.stream_args("/ok", %{"a" => "b", "c" => "d"},
          base_url: "http://example.com",
          api_key: "efg",
          type: MBTAV3API.Stop
        )

      assert args == [
               url: "http://example.com/ok?a=b&c=d",
               headers: [{"x-api-key", "efg"}],
               destination: self(),
               type: MBTAV3API.Stop
             ]
    end

    test "preserves topic if provided" do
      args =
        MBTAV3API.stream_args("/ok", %{"a" => "b", "c" => "d"},
          base_url: "http://example.com",
          api_key: "efg",
          destination: "some:topic",
          type: MBTAV3API.Trip
        )

      assert args == [
               url: "http://example.com/ok?a=b&c=d",
               headers: [{"x-api-key", "efg"}],
               destination: "some:topic",
               type: MBTAV3API.Trip
             ]
    end
  end
end

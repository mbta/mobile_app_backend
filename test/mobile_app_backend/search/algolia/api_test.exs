defmodule MobileAppBackend.Search.Algolia.ApiTest do
  use ExUnit.Case
  alias MobileAppBackend.Search.Algolia.{Api, QueryPayload, RouteResult, StopResult}

  import Test.Support.Helpers

  describe "multi_index_search/2" do
    test "when request is successful, returns flattened list of parsed results" do
      reassign_env(:mobile_app_backend, :algolia_perform_request_fn, &mock_perform_request_fn/3)

      assert {:ok, results} =
               Api.multi_index_search([
                 QueryPayload.for_index(:stop, "1"),
                 QueryPayload.for_index(:route, "1")
               ])

      assert %{
               stops: [
                 %StopResult{
                   type: :stop,
                   id: "place-FR-3338",
                   name: "Wachusett",
                   zone: "8",
                   station?: true,
                   rank: 3,
                   routes: [%{type: :commuter_rail, icon: "commuter_rail"}]
                 }
               ],
               routes: [
                 %RouteResult{
                   type: :route,
                   id: "33",
                   name: "33Name",
                   long_name: "33 Long Name",
                   rank: 5,
                   route_type: :bus
                 }
               ]
             } == results
    end

    test "makes requests to the algolia endpoint with expected headers and parameters properly encoded" do
      pid = self()

      default_env = Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.Search.Algolia,
        Keyword.merge(default_env,
          search_key: "fake_search_key",
          app_id: "fake_app_id"
        )
      )

      reassign_env(:mobile_app_backend, :algolia_perform_request_fn, fn url, body, headers ->
        send(pid, %{url: url, body: body, headers: headers})
        {:ok, %{body: %{"results" => []}}}
      end)

      Api.multi_index_search([
        QueryPayload.for_index(:stop, "1"),
        QueryPayload.for_index(:route, "1")
      ])

      assert_received(%{url: url, body: body, headers: headers})

      assert "fake_url/1/indexes/*/queries" == url

      assert ~s({"requests":[{"indexName":"stops_test","params":"analytics=false&clickAnalytics=true&hitsPerPage=10&query=1"},{"indexName":"routes_test","params":"analytics=false&clickAnalytics=true&hitsPerPage=5&query=1"}]}) ==
               body

      assert [
               {"X-Algolia-API-Key", "fake_search_key"},
               {"X-Algolia-Application-Id", "fake_app_id"}
             ] == headers
    end

    @tag capture_log: true
    test "when config missing, returns error" do
      default_env = Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.Search.Algolia,
        Keyword.merge(default_env, search_key: nil)
      )

      reassign_env(:mobile_app_backend, :algolia_perform_request_fn, &mock_perform_request_fn/3)

      assert {:error, :search_failed} =
               Api.multi_index_search([
                 QueryPayload.for_index(:stop, "1"),
                 QueryPayload.for_index(:route, "1")
               ])
    end

    @tag capture_log: true
    test "when invalid json, returns error" do
      reassign_env(:mobile_app_backend, :algolia_perform_request_fn, fn _url, _body, _headers ->
        {:ok, %{body: "[123 this is not json]"}}
      end)

      assert {:error, :malformed_results} =
               Api.multi_index_search([
                 QueryPayload.for_index(:stop, "1"),
                 QueryPayload.for_index(:route, "1")
               ])
    end

    @tag capture_log: true

    test "when request is unsuccessful, returns error" do
      reassign_env(:mobile_app_backend, :algolia_perform_request_fn, fn _url, _body, _headers ->
        {:error, "oops"}
      end)

      assert {:error, :search_failed} =
               Api.multi_index_search([
                 QueryPayload.for_index(:stop, "1"),
                 QueryPayload.for_index(:route, "1")
               ])
    end
  end

  def mock_perform_request_fn(_url, _body, _headers) do
    {:ok,
     %{
       body: %{
         "results" => [
           %{
             "index" => "stops_test",
             "hits" => [
               %{
                 "stop" => %{
                   "zone" => "8",
                   "station?" => true,
                   "name" => "Wachusett",
                   "id" => "place-FR-3338"
                 },
                 "routes" => [
                   %{
                     "type" => 2,
                     "icon" => "commuter_rail",
                     "display_name" => "Commuter Rail"
                   }
                 ],
                 "rank" => 3
               }
             ]
           },
           %{
             "index" => "routes_test",
             "hits" => [
               %{
                 "route" => %{
                   "type" => 3,
                   "name" => "33Name",
                   "long_name" => "33 Long Name",
                   "id" => "33"
                 },
                 "rank" => 5
               }
             ]
           }
         ]
       }
     }}
  end
end

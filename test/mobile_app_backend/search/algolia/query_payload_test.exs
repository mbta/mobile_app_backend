defmodule MobileAppBackend.Search.Algolia.QueryPayloadTest do
  use ExUnit.Case, async: true
  import Test.Support.Helpers
  alias MobileAppBackend.Search.Algolia.QueryPayload

  describe "new/2" do
    test "when for a route query, configures the index & params" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia,
        route_index: "fake_route_index"
      )

      assert %QueryPayload{
               index_name: "fake_route_index",
               params: %{
                 "query" => "testString",
                 "hitsPerPage" => 5,
                 "clickAnalytics" => true,
                 "analytics" => false
               }
             } == QueryPayload.for_index(:route, "testString")
    end

    test "when for a stop query, configures the index & params" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia,
        stop_index: "fake_stop_index"
      )

      assert %QueryPayload{
               index_name: "fake_stop_index",
               params: %{
                 "query" => "testString",
                 "hitsPerPage" => 10,
                 "clickAnalytics" => true,
                 "analytics" => false
               }
             } == QueryPayload.for_index(:stop, "testString")
    end

    test "when analytics is configured for the environment, then sets analytics param to true" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia, track_analytics?: true)

      assert %{params: %{"analytics" => true}} = QueryPayload.for_index(:route, "testString")
    end
  end
end

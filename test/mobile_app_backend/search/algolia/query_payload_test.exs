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
               },
               filters: ""
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
               },
               filters: ""
             } == QueryPayload.for_index(:stop, "testString")
    end

    test "when for a route filter, configures the index & params" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia,
        route_index: "fake_route_index"
      )

      assert %QueryPayload{
               index_name: "fake_route_index",
               params: %{
                 "query" => "testString",
                 "hitsPerPage" => 1000,
                 "clickAnalytics" => true,
                 "analytics" => false
               },
               filters: ""
             } == QueryPayload.for_route_filter("testString", %{})
    end

    test "applies multiple facet filters" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia,
        route_index: "fake_route_index"
      )

      assert %QueryPayload{
               index_name: "fake_route_index",
               params: %{
                 "query" => "testString",
                 "hitsPerPage" => 1000,
                 "clickAnalytics" => true,
                 "analytics" => false
               },
               filters:
                 "(facet_key_1:facet_term_1 OR facet_key_1:facet_term_2) AND (facet_key_2:facet_term_2)"
             } ==
               QueryPayload.for_route_filter("testString", %{
                 "facet_key_1" => "facet_term_1,facet_term_2",
                 "facet_key_2" => "facet_term_2"
               })
    end

    test "applies single facet filter" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia,
        route_index: "fake_route_index"
      )

      assert %QueryPayload{
               index_name: "fake_route_index",
               params: %{
                 "query" => "testString",
                 "hitsPerPage" => 1000,
                 "clickAnalytics" => true,
                 "analytics" => false
               },
               filters: "(facet_key:facet_term)"
             } == QueryPayload.for_route_filter("testString", %{"facet_key" => "facet_term"})
    end

    test "when analytics is configured for the environment, then sets analytics param to true" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia, track_analytics?: true)

      assert %{params: %{"analytics" => true}} = QueryPayload.for_index(:route, "testString")
    end
  end
end

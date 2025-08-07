defmodule MobileAppBackendWeb.SearchControllerTest do
  use MobileAppBackendWeb.ConnCase
  import Test.Support.Helpers
  alias MobileAppBackend.Search.Algolia.{QueryPayload, RouteResult, StopResult}

  describe "/api/search/query" do
    test "when query is an empty string, returns an empty list", %{conn: conn} do
      conn = get(conn, "/api/search/query?query=")

      assert %{"data" => %{}} =
               json_response(conn, 200)
    end

    test "when valid query string, returns search results", %{conn: conn} do
      stop = %StopResult{
        type: :stop,
        id: "place-FR-3338",
        name: "Wachusett",
        zone: "8",
        station?: true,
        rank: 3,
        routes: [%{type: 2, icon: "commuter_rail"}]
      }

      route = %RouteResult{
        type: :route,
        id: "33",
        name: "33Name",
        long_name: "33 Long Name",
        rank: 5,
        route_type: 3
      }

      reassign_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        fn _queries -> {:ok, %{stops: [stop], routes: [route]}} end
      )

      conn = get(conn, "/api/search/query?query=1")

      assert %{
               "data" => %{
                 "stops" => [
                   %{
                     "type" => "stop",
                     "id" => stop.id,
                     "name" => stop.name,
                     "zone" => stop.zone,
                     "station?" => stop.station?,
                     "rank" => stop.rank,
                     "routes" => [%{"type" => 2, "icon" => "commuter_rail"}]
                   }
                 ],
                 "routes" => [
                   %{
                     "type" => "route",
                     "id" => route.id,
                     "name" => route.name,
                     "long_name" => route.long_name,
                     "rank" => route.rank,
                     "route_type" => route.route_type
                   }
                 ]
               }
             } ==
               json_response(conn, 200)
    end

    @tag capture_log: true
    test "when there is an error performing algolia search, returns an error", %{conn: conn} do
      reassign_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        fn _queries -> {:error, "something_went_wrong"} end
      )

      conn = get(conn, "/api/search/query?query=1")

      assert %{
               "error" => "search_failed"
             } ==
               json_response(conn, 500)
    end
  end

  describe "/api/search/routes" do
    test "when query is an empty string, returns an empty list", %{conn: conn} do
      conn = get(conn, "/api/search/routes?query=")

      assert %{"data" => %{}} =
               json_response(conn, 200)
    end

    test "when valid query string, returns search results", %{conn: conn} do
      route = %RouteResult{
        type: :route,
        id: "33",
        name: "33Name",
        long_name: "33 Long Name",
        rank: 5,
        route_type: 3
      }

      reassign_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        fn _queries -> {:ok, %{routes: [route]}} end
      )

      conn = get(conn, "/api/search/routes?query=1")

      assert %{
               "data" => %{
                 "routes" => [
                   %{
                     "type" => "route",
                     "id" => route.id,
                     "name" => route.name,
                     "long_name" => route.long_name,
                     "rank" => route.rank,
                     "route_type" => route.route_type
                   }
                 ]
               }
             } ==
               json_response(conn, 200)
    end

    test "when type or line is included, applies facet filter", %{conn: conn} do
      route = %RouteResult{
        type: :route,
        id: "33",
        name: "33Name",
        long_name: "33 Long Name",
        rank: 5,
        route_type: 3
      }

      reassign_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        fn queries ->
          assert [
                   %QueryPayload{
                     filters:
                       "(route.line_id:line-33 OR route.line_id:line-other) AND (route.type:3)"
                   }
                 ] = queries

          {:ok, %{routes: [route]}}
        end
      )

      conn = get(conn, "/api/search/routes?query=1&type=bus&line_id=line-33,line-other")

      assert %{
               "data" => %{
                 "routes" => [
                   %{
                     "type" => "route",
                     "id" => route.id,
                     "name" => route.name,
                     "long_name" => route.long_name,
                     "rank" => route.rank,
                     "route_type" => route.route_type
                   }
                 ]
               }
             } ==
               json_response(conn, 200)
    end

    test "when comma separated type is included, properly parses into type IDs", %{conn: conn} do
      route = %RouteResult{
        type: :route,
        id: "Red",
        name: "Red",
        long_name: "Red Line",
        rank: 5,
        route_type: 1
      }

      reassign_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        fn queries ->
          assert [%QueryPayload{filters: "(route.type:1 OR route.type:0)"}] = queries

          {:ok, %{routes: [route]}}
        end
      )

      conn = get(conn, "/api/search/routes?query=Red&type=heavy_rail,light_rail")

      assert %{
               "data" => %{
                 "routes" => [
                   %{
                     "type" => "route",
                     "id" => route.id,
                     "name" => route.name,
                     "long_name" => route.long_name,
                     "rank" => route.rank,
                     "route_type" => route.route_type
                   }
                 ]
               }
             } ==
               json_response(conn, 200)
    end

    test "when invalid type is included, return empty type filter", %{conn: conn} do
      route = %RouteResult{
        type: :route,
        id: "Red",
        name: "Red",
        long_name: "Red Line",
        rank: 5,
        route_type: 1
      }

      reassign_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        fn queries ->
          assert [%QueryPayload{filters: ""}] = queries

          {:ok, %{routes: [route]}}
        end
      )

      conn = get(conn, "/api/search/routes?query=Red&type=teleporter")

      assert %{
               "data" => %{
                 "routes" => [
                   %{
                     "type" => "route",
                     "id" => route.id,
                     "name" => route.name,
                     "long_name" => route.long_name,
                     "rank" => route.rank,
                     "route_type" => route.route_type
                   }
                 ]
               }
             } ==
               json_response(conn, 200)
    end

    @tag capture_log: true
    test "when there is an error performing algolia search, returns an error", %{conn: conn} do
      reassign_env(
        :mobile_app_backend,
        :algolia_multi_index_search_fn,
        fn _queries -> {:error, "something_went_wrong"} end
      )

      conn = get(conn, "/api/search/routes?query=1")

      assert %{
               "error" => "search_failed"
             } ==
               json_response(conn, 500)
    end
  end
end

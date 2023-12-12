defmodule MobileAppBackendWeb.SchemaTest do
  use MobileAppBackendWeb.ConnCase

  import Test.Support.Helpers

  setup do
    Routes.Repo.clear_cache()
    Stops.Repo.clear_cache()

    :ok
  end

  @stop_query """
  query {
    stop(id: "place-boyls") {
      id
      name
      routes {
        id
        name
        routePatterns {
          id
          name
        }
      }
    }
  }
  """

  test "query: stop", %{conn: conn} do
    bypass_api()

    conn =
      post(conn, "/graphql", %{
        "query" => @stop_query
      })

    assert %{"data" => %{"stop" => stop_data}} = json_response(conn, 200)
    assert %{"id" => "place-boyls", "name" => "Boylston", "routes" => routes} = stop_data

    routes = Enum.sort_by(routes, & &1["id"])

    assert routes |> Enum.map(& &1["id"]) == [
             "Green-B",
             "Green-C",
             "Green-D",
             "Green-E"
           ]

    assert %{
             "id" => "Green-B",
             "name" => "Green Line B",
             "routePatterns" => route_patterns
           } = hd(routes)

    assert length(route_patterns) > 0
  end
end

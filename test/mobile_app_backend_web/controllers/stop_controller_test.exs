defmodule MobileAppBackendWeb.StopControllerTest do
  use MobileAppBackendWeb.ConnCase

  import Test.Support.Helpers

  setup do
    Routes.Repo.clear_cache()
    Stops.Repo.clear_cache()

    :ok
  end

  describe "/jsonapi/stop/place-boyls" do
    test "defaults to all fields no includes", %{conn: conn} do
      conn = get(conn, ~p"/jsonapi/stop/place-boyls")

      assert %{"data" => %{"id" => "place-boyls", "type" => "stop"}, "included" => []} =
               json_response(conn, 200)
    end

    test "processes includes", %{conn: conn} do
      bypass_api()

      conn = get(conn, ~p"/jsonapi/stop/place-boyls", %{include: "routes,routes.route_patterns"})

      assert %{"data" => %{}, "included" => included} = json_response(conn, 200)

      included =
        included
        |> Map.new(fn %{"type" => type, "id" => id, "attributes" => attributes} ->
          {{type, id}, attributes}
        end)

      assert Map.has_key?(included, {"route", "Green-B"})
      assert Map.has_key?(included, {"routePattern", "Green-B-812-0"})
    end
  end
end

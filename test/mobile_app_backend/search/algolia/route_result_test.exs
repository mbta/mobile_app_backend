defmodule MobileAppBackend.Search.Algolia.RouteResultTest do
  use ExUnit.Case, async: true
  alias MobileAppBackend.Search.Algolia.RouteResult

  describe "parse/1" do
    test "parses relevant route data fields" do
      response = %{
        "route" => %{
          "type" => 3,
          "name" => "33Name",
          "long_name" => "33 Long Name",
          "id" => "33"
        },
        "rank" => 5
      }

      assert %RouteResult{
               type: :route,
               id: "33",
               name: "33Name",
               long_name: "33 Long Name",
               rank: 5,
               route_type: 3
             } == RouteResult.parse(response)
    end
  end
end

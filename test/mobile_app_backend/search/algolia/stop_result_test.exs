defmodule MobileAppBackend.Search.Algolia.StopResultTest do
  use ExUnit.Case, async: true
  alias MobileAppBackend.Search.Algolia.StopResult

  describe "parse/1" do
    test "parses relevant stop data fields" do
      response = %{
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

      assert %StopResult{
               type: :stop,
               id: "place-FR-3338",
               name: "Wachusett",
               zone: "8",
               station?: true,
               rank: 3,
               routes: [%{type: :commuter_rail, icon: "commuter_rail"}]
             } == StopResult.parse(response)
    end
  end
end

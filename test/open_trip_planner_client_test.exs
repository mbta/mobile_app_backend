defmodule OpenTripPlannerClientTest do
  use HttpStub.Case, async: true

  describe "nearby/3" do
    test "handles parent stops" do
      assert {:ok,
              [
                %MBTAV3API.Stop{
                  id: "7097",
                  parent_station: %MBTAV3API.Stop{id: "place-aport"} = airport
                },
                %MBTAV3API.Stop{id: "7096", parent_station: airport},
                %MBTAV3API.Stop{id: "70048", parent_station: airport},
                %MBTAV3API.Stop{id: "70047", parent_station: airport}
              ]} =
               OpenTripPlannerClient.nearby(42.37434840767488, -71.03021663692962, 100)
    end
  end
end

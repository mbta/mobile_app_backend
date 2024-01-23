defmodule OpenTripPlannerClientTest do
  use ExUnit.Case, async: true
  import OpenTripPlannerClient
  alias OpenTripPlannerClient.NamedPosition

  describe "plan/3" do
    test "bad options returns an error" do
      expected = {:error, {:bad_param, {:bad, :arg}}}

      actual =
        plan(%NamedPosition{latitude: 1, longitude: 1}, %NamedPosition{latitude: 2, longitude: 2},
          bad: :arg
        )

      assert expected == actual
    end
  end
end

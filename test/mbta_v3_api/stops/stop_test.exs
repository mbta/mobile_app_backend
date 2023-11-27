defmodule Stops.StopTest do
  use ExUnit.Case

  alias Stops.Stop

  describe "accessibility_known?/1" do
    test "returns true if accessibilty isn't unknown" do
      refute Stop.accessibility_known?(%Stop{accessibility: ["unknown"]})
    end
  end

  describe "accessible?/1" do
    test "returns true if accessible" do
      assert Stop.accessible?(%Stop{accessibility: ["accessible"]})
      refute Stop.accessible?(%Stop{})
    end
  end

  # TODO: Restore test once we've restored Stop.has_zone?
  # describe "has_zone?/1" do
  #   test "returns true if there is a zone" do
  #     assert Stop.has_zone?(%Stop{zone: "1A"})
  #     refute Stop.has_zone?(%Stop{})
  #     refute Stop.has_zone?(%Stop{zone: nil})
  #   end
  # end
end

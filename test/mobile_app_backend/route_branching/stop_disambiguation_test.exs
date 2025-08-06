defmodule MobileAppBackend.RouteBranching.StopDisambiguationTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory
  alias MobileAppBackend.RouteBranching.StopDisambiguation

  describe "typicalities_stops_with_counts/1" do
    test "assigns counts to a single pattern that loops" do
      pattern = build(:route_pattern, typicality: :typical)

      assert StopDisambiguation.pattern_stops_with_counts(
               [{pattern, ~w(A B C D E C)}],
               ~w(A B C D E)
             ) == [
               {pattern, [{"A", 1}, {"B", 1}, {"C", 1}, {"D", 1}, {"E", 1}, {"C", 2}]}
             ]
    end

    test "gives a higher count to less typical loops even if they come earlier in the stop list" do
      typical_pattern = build(:route_pattern, typicality: :typical)
      atypical_pattern = build(:route_pattern, typicality: :atypical)

      assert StopDisambiguation.pattern_stops_with_counts(
               [
                 {typical_pattern, ~w(A B C)},
                 {atypical_pattern, ~w(C A B C)}
               ],
               ~w(A B C)
             ) == [
               {typical_pattern, [{"A", 1}, {"B", 1}, {"C", 1}]},
               {atypical_pattern, [{"C", 2}, {"A", 1}, {"B", 1}, {"C", 1}]}
             ]
    end

    test "even handles the ferry mess that looked impossible" do
      [pattern1, pattern2] = build_pair(:route_pattern, typicality: :typical)

      assert StopDisambiguation.pattern_stops_with_counts(
               [
                 {pattern1, ~w(Boat-Winthrop Boat-Aquarium Boat-Fan Boat-Logan Boat-Winthrop)},
                 {pattern2, ~w(Boat-Winthrop Boat-Logan Boat-Aquarium Boat-Fan Boat-Winthrop)}
               ],
               ~w(Boat-Winthrop Boat-Logan Boat-Aquarium Boat-Fan)
             ) == [
               {pattern1,
                [
                  {"Boat-Winthrop", 1},
                  {"Boat-Aquarium", 1},
                  {"Boat-Fan", 1},
                  {"Boat-Logan", 2},
                  {"Boat-Winthrop", 2}
                ]},
               {pattern2,
                [
                  {"Boat-Winthrop", 1},
                  {"Boat-Logan", 1},
                  {"Boat-Aquarium", 1},
                  {"Boat-Fan", 1},
                  {"Boat-Winthrop", 2}
                ]}
             ]
    end
  end
end

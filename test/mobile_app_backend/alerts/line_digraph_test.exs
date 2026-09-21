defmodule MobileAppBackend.Alerts.AlertSummary.LineDigraphTest do
  use ExUnit.Case

  alias MobileAppBackend.Alerts.AlertSummary.LineDigraph
  alias MobileAppBackend.GlobalDataCache

  describe "build_stops_digraph_from_patterns/3" do
    test "digraph includes correct stops" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()

      # Stops in B and C Lines
      stops = ["place-kencl", "place-bland", "place-smary"]

      # Stops not in B and C Lines
      not_in_lines = ["place-prmnl", "place-unsqu"]

      route_pattern_b = global.route_patterns["Green-B-812-0"]
      route_pattern_c = global.route_patterns["Green-C-832-0"]

      digraph =
        LineDigraph.build_stops_digraph_from_patterns(
          [route_pattern_b, route_pattern_c],
          0,
          global
        )

      assert stops |> Enum.all?(&(:digraph.vertex(digraph, &1) != false))
      assert not_in_lines |> Enum.all?(&(:digraph.vertex(digraph, &1) == false))
    end
  end

  describe "remove_unreachable_stops_from_digraph/2" do
    test "removes stops that cannot be reached from the digraph" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()

      # Reachable stops
      stops = ["place-kencl", "place-bland", "place-smary", "place-balsq"]

      # Unreachable stops
      not_in_lines = ["place-prmnl", "place-hsmnl"]

      route_pattern_b = global.route_patterns["Green-B-812-0"]
      route_pattern_c = global.route_patterns["Green-C-832-0"]
      route_pattern_e = global.route_patterns["Green-E-886-0"]

      digraph =
        LineDigraph.build_stops_digraph_from_patterns(
          [route_pattern_b, route_pattern_c, route_pattern_e],
          0,
          global
        )

      result = LineDigraph.remove_unreachable_stops_from_digraph(digraph, "place-kencl")

      assert result == :ok
      assert stops |> Enum.all?(&(:digraph.vertex(digraph, &1) != false))
      assert not_in_lines |> Enum.all?(&(:digraph.vertex(digraph, &1) == false))
    end

    test "returns error when target stop is not found in the digraph" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()

      route_pattern_b = global.route_patterns["Green-B-812-0"]

      digraph =
        LineDigraph.build_stops_digraph_from_patterns(
          [route_pattern_b],
          0,
          global
        )

      result = LineDigraph.remove_unreachable_stops_from_digraph(digraph, "place-nonexistent")

      assert result == {:error, :stop_not_found}
    end
  end

  describe "remove_unaffected_stops/2" do
    test "removes stops that are not affected by the given pattern stop map" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()

      route_pattern_b = global.route_patterns["Green-B-812-0"]
      route_pattern_c = global.route_patterns["Green-C-832-0"]

      # Affected stops
      stops = ["place-kencl", "place-bland", "place-smary"]

      # Unaffected stops
      unaffected_stops = ["place-prmnl", "place-hsmnl"]

      digraph =
        LineDigraph.build_stops_digraph_from_patterns(
          [route_pattern_b, route_pattern_c],
          0,
          global
        )

      affected_pattern_stops = %{
        route_pattern_b.id => ["place-kencl", "place-bland"],
        route_pattern_c.id => ["place-kencl", "place-smary"]
      }

      LineDigraph.remove_unaffected_stops(digraph, affected_pattern_stops)

      assert stops |> Enum.all?(&(:digraph.vertex(digraph, &1) != false))
      assert unaffected_stops |> Enum.all?(&(:digraph.vertex(digraph, &1) == false))
    end
  end

  describe "get_first_stops/2" do
    test "returns the first stops of the digraph" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()

      route_pattern_b = global.route_patterns["Green-B-812-0"]
      route_pattern_c = global.route_patterns["Green-C-832-0"]

      digraph =
        LineDigraph.build_stops_digraph_from_patterns(
          [route_pattern_b, route_pattern_c],
          0,
          global
        )

      first_stops = LineDigraph.get_first_stops(digraph, global)

      assert length(first_stops) == 1
      assert Enum.any?(first_stops, &(&1.id == "place-gover"))
      assert Enum.all?(first_stops, &(&1.id != "place-north"))
    end
  end

  describe "get_last_stops/2" do
    test "returns the last stops of the digraph" do
      Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
      global = GlobalDataCache.get_data()

      route_pattern_b = global.route_patterns["Green-B-812-0"]
      route_pattern_c = global.route_patterns["Green-C-832-0"]

      digraph =
        LineDigraph.build_stops_digraph_from_patterns(
          [route_pattern_b, route_pattern_c],
          0,
          global
        )

      last_stops = LineDigraph.get_last_stops(digraph, global)

      assert length(last_stops) == 2
      assert Enum.any?(last_stops, &(&1.id == "place-lake"))
      assert Enum.any?(last_stops, &(&1.id == "place-clmnl"))
      assert Enum.all?(last_stops, &(&1.id != "place-river"))
    end
  end
end

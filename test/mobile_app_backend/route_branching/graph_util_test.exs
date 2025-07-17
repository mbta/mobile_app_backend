defmodule MobileAppBackend.RouteBranching.GraphUtilTest do
  use ExUnit.Case, async: true
  alias MobileAppBackend.RouteBranching.GraphUtil

  test "drop_skipping_edges handles skipped case" do
    graph = :digraph.new([:cyclic, :protected])
    :digraph.add_vertex(graph, "A")
    :digraph.add_vertex(graph, "B")
    :digraph.add_vertex(graph, "C")
    :digraph.add_edge(graph, {"A", "B"}, "A", "B", nil)
    :digraph.add_edge(graph, {"B", "C"}, "B", "C", nil)
    :digraph.add_edge(graph, {"A", "C"}, "A", "C", nil)
    assert graph |> :digraph.edges() |> Enum.sort() == [{"A", "B"}, {"A", "C"}, {"B", "C"}]
    GraphUtil.drop_skipping_edges(graph)
    assert graph |> :digraph.edges() |> Enum.sort() == [{"A", "B"}, {"B", "C"}]
  end
end

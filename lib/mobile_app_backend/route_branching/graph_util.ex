defmodule MobileAppBackend.RouteBranching.GraphUtil do
  @doc """
  If we have A->B->C and also A->C, we want to drop A->C so neither A nor C thinks it has an extra neighbor.
  In graph theory, this is called the [transitive reduction](https://en.wikipedia.org/wiki/Transitive_reduction), and
  there are probably better algorithms to calculate it than this.
  """
  @spec drop_skipping_edges(:digraph.graph()) :: :ok
  def drop_skipping_edges(graph) do
    edges_to_delete =
      :digraph.edges(graph)
      |> Enum.filter(fn {from, to} ->
        neighbors = :digraph.out_neighbours(graph, from)

        if length(neighbors) > 1 do
          # reaching_neighbours/2 returns the list of vertices V such that there is a path V->...->to,
          # and if to is in V then there is a cycle so deleting edges would make debugging harder
          reaching = :digraph_utils.reaching_neighbours([to], graph) |> MapSet.new()
          not MapSet.member?(reaching, to) and Enum.any?(neighbors, &MapSet.member?(reaching, &1))
        end
      end)

    for edge <- edges_to_delete do
      :digraph.del_edge(graph, edge)
    end

    :ok
  end
end

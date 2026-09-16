defmodule MobileAppBackend.Alerts.EndpointStops do
  alias MBTAV3API.Stop
  @typep traversal_fun_t() :: (UnrootedPolytree.Edges.t() -> [UnrootedPolytree.Node.t()])

  # Provides a tree of stops that are reachable from a given stop.
  # Reachable means that if going in the same direction either next or previous
  # the stop will be there. A stop that is on previous when the first move was next is not reachable
  @spec reachable_nodes_from_stop(UnrootedPolytree.t(), UnrootedPolytree.Node.id()) ::
          UnrootedPolytree.t()
  def reachable_nodes_from_stop(unrooted_polytree, stop_id) do
    case UnrootedPolytree.node_for_id(unrooted_polytree, stop_id) do
      {:ok, _node} ->
        {previous_node_ids, _visited} =
          node_ids_in_direction(unrooted_polytree, stop_id, :previous)

        {next_node_ids, _visited} =
          node_ids_in_direction(unrooted_polytree, stop_id, :next)

        node_ids =
          [stop_id | previous_node_ids ++ next_node_ids]
          |> MapSet.new()

        unrooted_polytree
        |> subtree_with_node_ids(node_ids, stop_id)

      :error ->
        %UnrootedPolytree{}
    end
  end

  defp node_ids_in_direction(unrooted_polytree, starting_node_id, direction) do
    node_ids_in_direction(
      unrooted_polytree,
      starting_node_id,
      direction,
      MapSet.new([starting_node_id])
    )
  end

  # Recursively traverses an UnrootedPolytree in a given direction, returning
  # a list of all node IDs that are reachable from the starting node in that
  # direction. It also returns a set of all visited node IDs to avoid cycles.
  @spec node_ids_in_direction(
          UnrootedPolytree.t(),
          UnrootedPolytree.Node.id(),
          :next | :previous,
          MapSet.t()
        ) ::
          {[UnrootedPolytree.Node.id()], MapSet.t()}
  defp node_ids_in_direction(unrooted_polytree, node_id, direction, visited) do
    unrooted_polytree
    |> UnrootedPolytree.edges_for_id(node_id)
    |> Map.fetch!(direction)
    |> Enum.reduce({[], visited}, fn next_node_id, {node_ids, visited} ->
      if MapSet.member?(visited, next_node_id) do
        {node_ids, visited}
      else
        visited = MapSet.put(visited, next_node_id)

        {child_node_ids, visited} =
          node_ids_in_direction(unrooted_polytree, next_node_id, direction, visited)

        {[next_node_id | child_node_ids] ++ node_ids, visited}
      end
    end)
  end

  # Constructs a subtree of an UnrootedPolytree containing only the nodes
  # specified in `node_ids`. The `starting_node_id` will be the root of the
  # resulting subtree.
  defp subtree_with_node_ids(
         %UnrootedPolytree{by_id: by_id, edges: edges},
         node_ids,
         starting_node_id
       ) do
    %UnrootedPolytree{
      by_id: Map.filter(by_id, fn {node_id, _node} -> MapSet.member?(node_ids, node_id) end),
      edges:
        edges
        |> Map.take(MapSet.to_list(node_ids))
        |> Map.new(fn {node_id, edges} ->
          {node_id,
           %UnrootedPolytree.Edges{
             next: Enum.filter(edges.next, &MapSet.member?(node_ids, &1)),
             previous: Enum.filter(edges.previous, &MapSet.member?(node_ids, &1))
           }}
        end),
      starting_nodes: [starting_node_id]
    }
  end

  # Traverses an UnrootedPolytree of stops using the `previous` field
  # on each node in order to traverse backwards to the first affected
  # stop. See `traverse_from_nodes/3` for more info.
  @spec first_stops(UnrootedPolytree.t()) :: [Stop.t()]
  def first_stops(stop_tree) do
    stop_tree
    |> traverse_from_nodes(stop_tree.starting_nodes, & &1.previous)
    |> Enum.map(& &1.value)
  end

  # Traverses an UnrootedPolytree of stops using the `next` field on
  # each node in order to traverse forwards to the last affected
  # stop. See `traverse_from_nodes/3` for more info.
  @spec last_stops(UnrootedPolytree.t()) :: [Stop.t()]
  def last_stops(stop_tree) do
    stop_tree
    |> traverse_from_nodes(stop_tree.starting_nodes, & &1.next)
    |> Enum.map(& &1.value)
  end

  # Traverses an UnrootedPolytree using the provided `traversal_fun`
  # to search recursively through the tree until it reaches a node
  # with no edges.
  #
  # It de-duplicates identical node ID's, so even if there are two
  # branches, if they arrive at the same stop in the end, then it only
  # returns that node once.
  @spec traverse_from_nodes(UnrootedPolytree.t(), [Stop.id()], traversal_fun_t()) ::
          [UnrootedPolytree.Node.t()]
  defp traverse_from_nodes(unrooted_polytree, node_ids, traversal_fun) do
    node_ids
    |> Enum.flat_map(&(unrooted_polytree |> traverse_from_node(&1, traversal_fun)))
    |> Enum.uniq_by(& &1.id)
  end

  # Helper function used by `traverse_from_nodes/3` to traverse an
  # UnrootedPolytree from a single node.
  @spec traverse_from_node(UnrootedPolytree.t(), Stop.id(), traversal_fun_t()) ::
          [UnrootedPolytree.Node.t()]
  defp traverse_from_node(unrooted_polytree, node_id, traversal_fun) do
    unrooted_polytree
    |> UnrootedPolytree.edges_for_id(node_id)
    |> Kernel.then(traversal_fun)
    |> case do
      [] ->
        # IO.inspect("No edges for node #{node_id}")
        unrooted_polytree
        |> UnrootedPolytree.node_for_id(node_id)
        |> case do
          {:ok, node} -> [node]
          _ -> []
        end

      edges ->
        # IO.inspect(edges, label: "Edges for node #{node_id}")
        unrooted_polytree |> traverse_from_nodes(edges, traversal_fun)
    end
  end
end

defmodule MobileAppBackend.RouteBranching.SegmentGraph do
  alias MobileAppBackend.RouteBranching.StopGraph

  defmodule Node do
    alias MBTAV3API.RoutePattern
    alias MBTAV3API.Stop
    @type t :: %__MODULE__{stops: [Stop.t()], typicalities: MapSet.t(RoutePattern.typicality())}
    defstruct [:stops, :typicalities]
  end

  @type t :: :digraph.graph()
  @type vertex_id :: StopGraph.vertex_id()
  @type edge_id :: {vertex_id(), vertex_id()}

  @spec build(StopGraph.t()) :: t()
  def build(stop_graph) do
    result = :digraph.new([:cyclic, :protected])

    for vertex <- :digraph_utils.topsort(stop_graph), reduce: MapSet.new() do
      seen ->
        if MapSet.member?(seen, vertex) do
          seen
        else
          {new_segment_node_ids, new_segment_neighbors} = full_segment(stop_graph, [vertex])

          new_segment_stop_nodes =
            new_segment_node_ids
            |> Enum.map(fn vertex ->
              {_, label} = :digraph.vertex(stop_graph, vertex)
              label
            end)

          new_segment_stops = new_segment_stop_nodes |> Enum.map(& &1.stop)

          new_segment_typicalities =
            new_segment_stop_nodes
            |> Enum.map(& &1.typicalities)
            |> Enum.reduce(MapSet.new(), &MapSet.union/2)

          :digraph.add_vertex(result, vertex, %Node{
            stops: new_segment_stops,
            typicalities: new_segment_typicalities
          })

          for neighbor <- new_segment_neighbors do
            if :digraph.vertex(result, neighbor) == false do
              :digraph.add_vertex(result, neighbor, nil)
            end

            {^vertex, ^neighbor} =
              :digraph.add_edge(result, {vertex, neighbor}, vertex, neighbor, nil)
          end

          MapSet.union(seen, MapSet.new(new_segment_node_ids))
        end
    end

    result
  end

  @spec full_segment(StopGraph.t(), [StopGraph.vertex_id()]) ::
          {segment :: [StopGraph.vertex_id()], next :: [StopGraph.vertex_id()]}
  defp full_segment(stop_graph, [this_stop | _] = reversed_segment) do
    case :digraph.out_neighbours(stop_graph, this_stop) do
      [next_stop] ->
        next_only_this_previous = :digraph.in_neighbours(stop_graph, next_stop) == [this_stop]

        {_, this_label} = :digraph.vertex(stop_graph, this_stop)
        {_, next_label} = :digraph.vertex(stop_graph, next_stop)
        this_typical = this_label.typicalities |> MapSet.member?(:typical)
        next_typical = next_label.typicalities |> MapSet.member?(:typical)

        if next_only_this_previous and this_typical == next_typical do
          full_segment(stop_graph, [next_stop | reversed_segment])
        else
          {Enum.reverse(reversed_segment), [next_stop]}
        end

      next_stops ->
        {Enum.reverse(reversed_segment), next_stops}
    end
  end
end

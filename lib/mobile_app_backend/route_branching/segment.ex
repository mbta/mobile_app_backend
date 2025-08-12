defmodule MobileAppBackend.RouteBranching.Segment do
  alias MBTAV3API.Stop
  alias MobileAppBackend.RouteBranching.Segment
  alias MobileAppBackend.RouteBranching.SegmentGraph

  @typep segment_id :: SegmentGraph.vertex_id()
  @typedoc """
  Every segment is in one of these three lanes; its stops have that horizontal position,
  and connections to and from it end and start in that horizontal position.
  """
  @type lane :: :left | :center | :right

  # while building the lane assignments, we represent the lanes as 0, 1, 2 rather than :left, :center, :right
  # so that they sort [0, 1, 2, nil] rather than [:center, :left, nil, :right]
  @typep lane_index :: 0 | 1 | 2

  defmodule StickConnection do
    @type vpos :: :top | :center | :bottom

    @type t :: %__MODULE__{
            from_stop: Stop.id(),
            to_stop: Stop.id(),
            from_lane: Segment.lane(),
            to_lane: Segment.lane(),
            from_vpos: vpos(),
            to_vpos: vpos()
          }
    @derive Jason.Encoder
    defstruct [:from_stop, :to_stop, :from_lane, :to_lane, :from_vpos, :to_vpos]
  end

  defmodule BranchStop do
    alias MBTAV3API.Stop

    @type t :: %__MODULE__{
            stop_id: Stop.id(),
            stop_lane: Segment.lane(),
            connections: [StickConnection.t()]
          }
    @derive Jason.Encoder
    defstruct [:stop_id, :stop_lane, :connections]
  end

  @type t :: %__MODULE__{stops: [BranchStop.t()], name: String.t() | nil, typical?: boolean()}
  @derive Jason.Encoder
  defstruct [:stops, :name, :typical?]

  @spec get_list_from_graph([segment_id()], SegmentGraph.t(), [String.t()]) ::
          {:ok, [t()]} | {:error, String.t()}
  def get_list_from_graph(segment_order, segment_graph, segment_name_candidates) do
    with {:ok, segment_lanes} <-
           set_segment_lanes(segment_order, segment_graph) do
      {:ok, connections_skipping_current} = Agent.start_link(fn -> [] end)

      result =
        segment_order
        |> Enum.with_index(fn segment_id, segment_index ->
          {_, segment} = :digraph.vertex(segment_graph, segment_id)

          Agent.update(connections_skipping_current, fn ssc ->
            Enum.reject(ssc, &(&1.to_stop == elem(segment_id, 0)))
          end)

          csc = Agent.get(connections_skipping_current, & &1)

          segment_lane = segment_lanes[segment_id]

          lanes_with_conflicts = get_lanes_with_conflict(csc, segment_id, segment_lane)

          if map_size(lanes_with_conflicts) > 0 do
            {:error,
             "Multiple segments on the same lane at the same time: #{inspect(lanes_with_conflicts)}"}
          else
            children = :digraph.out_neighbours(segment_graph, segment_id)

            incoming_from_parents =
              segment_neighbor_stops(
                segment_id,
                segment_lanes,
                segment_graph,
                &:digraph.in_neighbours/2,
                &List.last/1,
                &{&1, segment_id}
              )

            outgoing_to_children =
              segment_neighbor_stops(
                segment_id,
                segment_lanes,
                segment_graph,
                &:digraph.out_neighbours/2,
                &List.first/1,
                &{segment_id, &1}
              )

            next_segment_id = Enum.at(segment_order, segment_index + 1)
            subsequent_segments = Enum.reject(children, &(&1 == next_segment_id))

            segment_stops =
              build_segment_stops(
                segment.stops,
                segment_lane,
                incoming_from_parents,
                outgoing_to_children,
                csc
              )

            Agent.update(
              connections_skipping_current,
              &(&1 ++
                  connections_to_subsequent(
                    segment_id,
                    segment,
                    subsequent_segments,
                    segment_lanes,
                    segment_graph
                  ))
            )

            %__MODULE__{
              stops: segment_stops,
              name: get_segment_name(segment.stops, segment_name_candidates),
              typical?: MapSet.member?(segment.typicalities, :typical)
            }
          end
        end)

      Agent.stop(connections_skipping_current)

      Enum.find(result, {:ok, result}, &match?({:error, _}, &1))
    end
  end

  @spec get_segment_name([Stop.t()], [String.t()]) :: String.t() | nil
  def get_segment_name(segment_stops, segment_name_candidates) do
    Enum.find(segment_name_candidates, fn candidate ->
      regex = ~r"(\b|^)#{candidate}(\b|$)"
      Enum.any?(segment_stops, &Regex.match?(regex, &1.name))
    end)
  end

  @doc """
  Constructs a single segment with all stops with no connections. Used as a fallback if the graph-based process
  encountered an error.
  """
  @spec get_fallback([Stop.id()]) :: [t()]
  def get_fallback(stop_ids) do
    [
      %__MODULE__{
        stops:
          Enum.map(stop_ids, fn stop_id ->
            %BranchStop{stop_id: stop_id, stop_lane: :center, connections: []}
          end),
        name: nil,
        typical?: true
      }
    ]
  end

  # If the segment order has [A, B, C] with an edge A -> C, then that edge will be drawn next to B, so that edge
  # (and therefore whichever of A or C wins less_crowded_neighbor/2) needs to be in a different lane than B.
  # The less crowded of A or C will be a _parallel segment_ when evaluating B.
  #
  # The primary constraint on the lane assignment is that parallel segments must always be assigned to different
  # lanes. As such, segments with more parallel segments are more constrained.
  #
  # For changes in typicality that do not branch, we would prefer to keep those adjacent segments in the same lane;
  # if we have A -> B with no A -> C or C -> B, then B will inherit a lane from A if A is assigned a lane before B,
  # and if we have A -> B with no C -> B or A -> C, then A will inherit a lane from B if B is assigned a lane before A.
  #
  # Algorithm:
  # 1. Sort the segments by how constrained they are (see segment_constrainedness/2)
  # 2. For each segment from most constrained to least: (see segment_lanes_reducer/4)
  #   a. If this segment has already been assigned a lane, skip it
  #   b. Assign lanes to this segment and all its parallel segments:
  #     i. If a segment already has an assigned lane, keep it
  #     ii. If a segment should inherit a lane from its parent or child, use it (see segment_constrained_lane/3)
  #     iii. Assign other segments to other lanes, aiming to put two segments on the left and right and
  #            one segment in the center (see assign_segments/3)
  @spec set_segment_lanes([segment_id()], SegmentGraph.t()) ::
          {:ok, %{segment_id() => lane()}} | {:error, String.t()}
  defp set_segment_lanes(segment_order, segment_graph) do
    # initially, this used the Coffman-Graham algorithm, but we want to analyze a segment across all vertical positions
    # where it conflicts with other segments, not just at one level. plus we already have a topological sort
    segments_with_parallel =
      Enum.with_index(segment_order, fn current_segment, index ->
        segments_before = Enum.take(segment_order, index)
        segments_after = Enum.drop(segment_order, index + 1)

        segments_parallel =
          :digraph.edges(segment_graph)
          |> Enum.filter(fn {v1, v2} -> v1 in segments_before and v2 in segments_after end)
          |> Enum.map(fn {v1, v2} ->
            less_crowded_neighbor(segment_graph, {v1, v2})
          end)
          |> Enum.uniq()

        {index, current_segment, segments_parallel}
      end)

    if Enum.any?(segments_with_parallel, fn {_, _, parallel} -> length(parallel) > 2 end) do
      {:error, "A segment had more than two parallel segments"}
    else
      # rather than an iterative global approach that would be more likely to give an optimal result, we sort vertices
      # by constrainedness and then visit each vertex sequentially, for decent performance and implementation simplicity
      segments_with_parallel
      |> Enum.sort_by(
        fn {index, _, _} -> segment_constrainedness(index, segments_with_parallel) end,
        :desc
      )
      |> Enum.reduce(%{}, fn {_, segment, parallel_segments}, segment_lanes ->
        segment_lanes_reducer(segment, parallel_segments, segment_lanes, segment_graph)
      end)
      |> case do
        {:error, error} ->
          {:error, error}

        %{} = segment_lanes ->
          {:ok,
           Map.new(segment_lanes, fn
             {vertex, 0} -> {vertex, :left}
             {vertex, 1} -> {vertex, :center}
             {vertex, _} -> {vertex, :right}
           end)}
      end
    end
  end

  # Gets the map (which should be empty) of connections which are in the same lane but conflict with each other,
  # also checking for conflicts with the current segment in its lane.
  @spec get_lanes_with_conflict([StickConnection.t()], segment_id(), lane()) :: %{
          lane() => [StickConnection.t()]
        }
  defp get_lanes_with_conflict(connections_skipping_current, segment_id, segment_lane) do
    Enum.group_by(connections_skipping_current, & &1.to_lane)
    |> update_in([segment_lane], fn existing_connections ->
      {stop_id, _} = segment_id

      new_conn = %StickConnection{
        from_stop: stop_id,
        to_stop: stop_id,
        from_lane: segment_lane,
        to_lane: segment_lane,
        from_vpos: :center,
        to_vpos: :center
      }

      [new_conn | existing_connections || []]
    end)
    |> Map.filter(fn {_lane, connections_in_lane} ->
      # if there are multiple connections in the same lane, that’s legal if they’re either
      # all from the same stop or all to the same stop
      if length(connections_in_lane) > 1 do
        from_all_match? =
          connections_in_lane
          |> Enum.uniq_by(& &1.from_stop)
          |> length()
          |> then(&(&1 == 1))

        to_all_match? =
          connections_in_lane
          |> Enum.uniq_by(& &1.from_stop)
          |> length()
          |> then(&(&1 == 1))

        not (from_all_match? or to_all_match?)
      end
    end)
  end

  # Turns A->C B->C into [{last stop of A, lane of {A, C}}, {last stop of B, lane of {A, B}}] or
  # A->B A->C into [{first stop of B, lane of {A, B}}, {first stop of C, lane of {A, C}}],
  # using less_crowded_neighbor/2 to assign lanes to edges.
  @spec segment_neighbor_stops(
          segment_id(),
          %{segment_id() => lane()},
          SegmentGraph.t(),
          (:digraph.graph(), :digraph.vertex() -> [:digraph.vertex()]),
          ([Stop.t()] -> Stop.t()),
          (segment_id() -> {segment_id(), segment_id()})
        ) :: [{Stop.id(), lane()}]
  defp segment_neighbor_stops(
         segment_id,
         segment_lanes,
         segment_graph,
         get_neighbors,
         get_stop_from_list,
         build_edge_tuple
       ) do
    get_neighbors.(segment_graph, segment_id)
    |> Enum.map(fn neighbor ->
      {_, neighbor_segment} = :digraph.vertex(segment_graph, neighbor)
      neighbor_stop = get_stop_from_list.(neighbor_segment.stops).id
      lane = segment_lanes[less_crowded_neighbor(segment_graph, build_edge_tuple.(neighbor))]
      {neighbor_stop, lane}
    end)
    |> Enum.sort()
  end

  # The edge A -> B will be drawn in either A’s lane or B’s lane, and this is the function that decides which one.
  # We want the edges to spread out closer to the more crowded neighbor,
  # so we use the lane of the less crowded neighbor, with ties going to the parent.
  @spec less_crowded_neighbor(:digraph.graph(), {:digraph.vertex(), :digraph.vertex()}) ::
          :digraph.vertex()
  defp less_crowded_neighbor(segment_graph, {from, to}) do
    if :digraph.out_degree(segment_graph, from) <= :digraph.in_degree(segment_graph, to) do
      from
    else
      to
    end
  end

  # Turns the list of Stops into a list of BranchStops with the relevant StickConnections
  # (see build_segment_stop_connections/6).
  @spec build_segment_stops(
          [Stop.t()],
          lane(),
          [{Stop.id(), lane()}],
          [{Stop.id(), lane()}],
          [StickConnection.t()]
        ) ::
          [BranchStop.t()]
  defp build_segment_stops(
         segment_stops,
         segment_lane,
         incoming_from_parents,
         outgoing_to_children,
         connections_skipping_current
       ) do
    Enum.with_index(segment_stops, fn stop, stop_index ->
      previous_stop = if stop_index > 0, do: Enum.at(segment_stops, stop_index - 1)
      next_stop = Enum.at(segment_stops, stop_index + 1)

      stop_connections =
        build_segment_stop_connections(
          stop,
          previous_stop,
          next_stop,
          segment_lane,
          incoming_from_parents,
          outgoing_to_children
        )

      %BranchStop{
        stop_id: stop.id,
        stop_lane: segment_lane,
        connections: stop_connections ++ connections_skipping_current
      }
    end)
  end

  # Computes the list of connections from this segment to its children after the next segment;
  # these are the connections which will be skipping segments.
  @spec connections_to_subsequent(
          segment_id(),
          SegmentGraph.Node.t(),
          [segment_id()],
          %{segment_id() => lane()},
          SegmentGraph.t()
        ) :: [StickConnection.t()]
  defp connections_to_subsequent(
         segment_id,
         segment,
         subsequent_segments,
         segment_lanes,
         segment_graph
       ) do
    from_stop = List.last(segment.stops).id

    Enum.map(
      subsequent_segments,
      fn to_segment ->
        lane =
          segment_lanes[
            less_crowded_neighbor(segment_graph, {segment_id, to_segment})
          ]

        {to_stop, _} = to_segment

        %StickConnection{
          from_stop: from_stop,
          to_stop: to_stop,
          from_lane: lane,
          to_lane: lane,
          from_vpos: :top,
          to_vpos: :bottom
        }
      end
    )
  end

  # Intuitively, segments with more parallel segments are more constrained, and segments adjacent to more
  # constrained segments are more constrained.
  # Mathematically, constrainedness comes from the number of parallel segments at each segment, with
  # inverse-square falloff.
  @spec segment_constrainedness(non_neg_integer(), [
          {non_neg_integer(), segment_id(), [segment_id()]}
        ]) :: float()
  defp segment_constrainedness(index, segments_with_parallel) do
    segments_with_parallel
    |> Enum.sum_by(fn {other_index, _, other_parallel} ->
      length(other_parallel) / Integer.pow(abs(other_index - index) + 1, 2)
    end)
  end

  # Update a segment_lanes map with the new lane assignments for the given segment and its parallel segments
  # (see segment_constrained_lane/3 and assign_segments/3).
  @spec segment_lanes_reducer(
          segment_id(),
          [segment_id()],
          %{segment_id() => lane_index()} | {:error, String.t()},
          SegmentGraph.t()
        ) :: %{segment_id() => lane_index()} | {:error, String.t()}
  defp segment_lanes_reducer(segment, parallel_segments, segment_lanes, segment_graph) do
    case segment_lanes do
      {:error, error} ->
        {:error, error}

      %{^segment => _} ->
        segment_lanes

      _ ->
        lane_to_segment =
          [segment | parallel_segments]
          |> Enum.group_by(&segment_constrained_lane(&1, segment_graph, segment_lanes))
          |> Map.filter(fn {lane, segments} -> not is_nil(lane) and length(segments) == 1 end)
          |> Map.new(fn {lane, [segment]} -> {lane, segment} end)

        segment_to_lane =
          Map.new(lane_to_segment, fn {lane, segment} -> {segment, lane} end)

        unconstrained_lanes = [0, 1, 2] -- Map.keys(lane_to_segment)

        unconstrained_segments =
          [segment | Enum.sort(parallel_segments)] -- Map.keys(segment_to_lane)

        case assign_segments(unconstrained_segments, unconstrained_lanes, segment_to_lane) do
          {:error, error} ->
            {:error, error}

          %{} = extra_assignments ->
            new_assignments = Map.merge(segment_to_lane, extra_assignments)

            Map.merge(segment_lanes, new_assignments)
        end
    end
  end

  # Constructs the connections for an individual stop, to either its previous/next stop
  # (if it’s in the middle of a segment) or the incoming/outgoing segment connections
  # (if it’s at the start/end of a segment).
  @spec build_segment_stop_connections(
          Stop.t(),
          Stop.t() | nil,
          Stop.t() | nil,
          lane(),
          [{Stop.id(), lane()}],
          [{Stop.id(), lane()}]
        ) :: [StickConnection.t()]
  defp build_segment_stop_connections(
         stop,
         previous_stop,
         next_stop,
         segment_lane,
         incoming_from_parents,
         outgoing_to_children
       ) do
    connections_before =
      if is_nil(previous_stop) do
        Enum.map(incoming_from_parents, fn {parent_stop, parent_lane} ->
          %StickConnection{
            from_stop: parent_stop,
            to_stop: stop.id,
            from_lane: parent_lane,
            to_lane: segment_lane,
            from_vpos: :top,
            to_vpos: :center
          }
        end)
      else
        [
          %StickConnection{
            from_stop: previous_stop.id,
            to_stop: stop.id,
            from_lane: segment_lane,
            to_lane: segment_lane,
            from_vpos: :top,
            to_vpos: :center
          }
        ]
      end

    connections_after =
      if is_nil(next_stop) do
        Enum.map(outgoing_to_children, fn {child_stop, child_lane} ->
          %StickConnection{
            from_stop: stop.id,
            to_stop: child_stop,
            from_lane: segment_lane,
            to_lane: child_lane,
            from_vpos: :center,
            to_vpos: :bottom
          }
        end)
      else
        [
          %StickConnection{
            from_stop: stop.id,
            to_stop: next_stop.id,
            from_lane: segment_lane,
            to_lane: segment_lane,
            from_vpos: :center,
            to_vpos: :bottom
          }
        ]
      end

    connections_before ++ connections_after
  end

  # If this segment has already been assigned a lane, or if it should inherit a lane from its parent/child,
  # it must have that lane and should not be passed to `assign_segments/3`.
  @spec segment_constrained_lane(segment_id(), SegmentGraph.t(), %{segment_id() => lane_index()}) ::
          lane_index() | nil
  defp segment_constrained_lane(segment, segment_graph, segment_lanes) do
    if already_assigned_lane = segment_lanes[segment] do
      already_assigned_lane
    else
      parent_lane =
        segment_lanes[
          neighbor_constraint(
            segment_graph,
            segment,
            &:digraph.in_neighbours/2,
            &:digraph.out_degree/2
          )
        ]

      child_lane =
        segment_lanes[
          neighbor_constraint(
            segment_graph,
            segment,
            &:digraph.out_neighbours/2,
            &:digraph.in_degree/2
          )
        ]

      # if one is nil, we take the other, but if neither is nil, we only take if they’re the same
      case {parent_lane, child_lane} do
        {lane, lane} -> lane
        {lane, nil} -> lane
        {nil, lane} -> lane
        _ -> nil
      end
    end
  end

  # Fill unoccupied lanes with the segments that did not have a constraint (see segment_constrained_lane/3).
  # Cases with multiple possible answers to choose from:
  # - If there is one segment but all lanes are open, put it in the center
  # - If there are two segments and all lanes are open, put them on the sides
  # - If there is one segment and one side is full but the center and the other side are open, take the other side
  # - If there is one segment and the center is full but the sides are open, take the left
  #
  # Assumes unconstrained_segments are in a deterministic order and unconstrained_lanes are sorted.
  @spec assign_segments([segment_id()], [lane_index()], %{segment_id() => lane_index()}) ::
          %{segment_id() => lane_index()} | {:error, String.t()}
  defp assign_segments(unconstrained_segments, unconstrained_lanes, constrained_segments_to_lanes)

  defp assign_segments([], _, _), do: %{}
  defp assign_segments([s], [t], _), do: %{s => t}
  defp assign_segments([s], [0, 1, 2], _), do: %{s => 1}
  defp assign_segments([s], [0, 1], _), do: %{s => 0}
  defp assign_segments([s], [1, 2], _), do: %{s => 2}
  defp assign_segments([s], [0, 2], _), do: %{s => 0}
  defp assign_segments([s1, s2], [t1, t2], _), do: %{s1 => t2, s2 => t1}
  defp assign_segments([s1, s2], [0, 1, 2], _), do: %{s1 => 2, s2 => 0}
  defp assign_segments([s1, s2, s3], [0, 1, 2], _), do: %{s1 => 2, s2 => 1, s3 => 0}

  # should not be possible
  defp assign_segments(segments, _, constrained_segments_to_lanes) do
    {:error,
     "Bad extra_assignments: constrained_segments_to_lanes #{inspect(constrained_segments_to_lanes)}, unconstrained_segments #{segments}"}
  end

  # Checks if this vertex has only one neighbor and that neighbor has only this vertex coming the other direction;
  # i.e. if this vertex is its only parent’s only child or its only child’s only parent.
  @spec neighbor_constraint(
          :digraph.graph(),
          :digraph.vertex(),
          (:digraph.graph(), :digraph.vertex() -> [:digraph.vertex()]),
          (:digraph.graph(), :digraph.vertex() -> non_neg_integer())
        ) :: :digraph.vertex() | nil
  defp neighbor_constraint(graph, vertex, get_neighbors, reverse_degree) do
    graph
    |> get_neighbors.(vertex)
    |> case do
      [neighbor] ->
        if reverse_degree.(graph, neighbor) == 1 do
          neighbor
        end

      _ ->
        nil
    end
  end
end

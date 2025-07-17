defmodule MobileAppBackend.RouteBranching.Segment do
  alias MBTAV3API.Stop
  alias MobileAppBackend.RouteBranching.SegmentGraph

  @type stick_side :: :left | :right
  def opposite_side(:left), do: :right
  def opposite_side(:right), do: :left

  defmodule StickSideState do
    @moduledoc """
    - `before` is true if the stick diagram should be filled on this side above the center
    - `converging` is true if the stick diagram from this side and the other side should merge above the center
    - `current_stop` is true if the stop should be drawn in the center (or false if the stop is on the other side)
    - `diverging` is true if the stick diagram should fork to this side and the other side below the center
    - `after` is true if the stick diagram should be filled on this side below the center
    """
    @type t :: %__MODULE__{
            before: boolean(),
            converging: boolean(),
            current_stop: boolean(),
            diverging: boolean(),
            after: boolean()
          }
    @derive Jason.Encoder
    defstruct [:before, :converging, :current_stop, :diverging, :after]
  end

  defmodule StickState do
    @type t :: %__MODULE__{left: StickSideState.t(), right: StickSideState.t()}
    @derive Jason.Encoder
    defstruct [:left, :right]
  end

  defmodule BranchStop do
    alias MBTAV3API.Stop
    @type t :: %__MODULE__{stop_id: Stop.id(), stick_state: StickState.t()}
    @derive Jason.Encoder
    defstruct [:stop_id, :stick_state]
  end

  @type t :: %__MODULE__{stops: [BranchStop.t()], name: String.t() | nil, typical?: boolean()}
  @derive Jason.Encoder
  defstruct [:stops, :name, :typical?]

  @spec get_list_from_graph([SegmentGraph.vertex_id()], SegmentGraph.t(), [String.t()]) ::
          {:ok, [t()]} | {:error, String.t()}
  def get_list_from_graph(segment_order, segment_graph, segment_name_candidates) do
    with {:ok, segment_sides} <-
           set_segment_sides(segment_order, segment_graph, %{}, segment_order) do
      {:ok, segments_skipping_current} = Agent.start_link(fn -> MapSet.new() end)

      result =
        segment_order
        |> Enum.with_index(fn segment_id, segment_index ->
          {_, segment} = :digraph.vertex(segment_graph, segment_id)

          Agent.update(segments_skipping_current, &MapSet.delete(&1, segment_id))

          ssc = Agent.get(segments_skipping_current, & &1)

          if MapSet.size(ssc) > 1 do
            {:error, "Multiple segments skipping current: #{inspect(ssc)}"}
          else
            has_segment_skipping = Agent.get(segments_skipping_current, &(MapSet.size(&1) > 0))

            parents = :digraph.in_neighbours(segment_graph, segment_id)
            children = :digraph.out_neighbours(segment_graph, segment_id)

            parent_sides = Enum.map(parents, &segment_sides[&1])
            children_sides = Enum.map(children, &segment_sides[&1])

            segment_side = segment_sides[segment_id]

            next_segment_id = Enum.at(segment_order, segment_index + 1)
            subsequent_segment_connections = Enum.reject(children, &(&1 == next_segment_id))

            segment_stops =
              build_segment_stops(
                segment.stops,
                segment_side,
                parent_sides,
                children_sides,
                has_segment_skipping
              )

            Agent.update(
              segments_skipping_current,
              &MapSet.union(&1, MapSet.new(subsequent_segment_connections))
            )

            %__MODULE__{
              stops: segment_stops,
              name: get_segment_name(segment.stops, segment_name_candidates),
              typical?: MapSet.member?(segment.typicalities, :typical)
            }
          end
        end)

      Agent.stop(segments_skipping_current)

      Enum.find(result, {:ok, result}, &match?({:error, _}, &1))
    end
  end

  defp set_segment_sides(segment_order, segment_graph, finished_sides, segments_pending_side)

  defp set_segment_sides(_, _, finished_sides, []), do: {:ok, finished_sides}

  defp set_segment_sides(segment_order, segment_graph, finished_sides, [
         next_segment | remaining_segments
       ]) do
    parents = :digraph.in_neighbours(segment_graph, next_segment)

    if Enum.any?(parents, &(not Map.has_key?(finished_sides, &1))) do
      {:error, "Stop ID sequence out of order"}
    else
      parent_sides = parents |> MapSet.new(&finished_sides[&1])
      children = :digraph.out_neighbours(segment_graph, next_segment)

      siblings_up =
        parents
        |> Enum.flat_map(fn parent -> :digraph.out_neighbours(segment_graph, parent) end)

      siblings_down =
        children
        |> Enum.flat_map(fn child -> :digraph.in_neighbours(segment_graph, child) end)

      siblings =
        siblings_up
        |> MapSet.new()
        |> MapSet.union(MapSet.new(siblings_down))
        |> MapSet.delete(next_segment)

      sibling_sides = MapSet.new(siblings, &finished_sides[&1]) |> MapSet.delete(nil)

      next_side =
        cond do
          MapSet.size(sibling_sides) == 1 ->
            {:ok, opposite_side(hd(MapSet.to_list(sibling_sides)))}

          MapSet.size(sibling_sides) == 2 ->
            {:error, "Siblings on both sides"}

          MapSet.size(parent_sides) == 1 ->
            {:ok, hd(MapSet.to_list(parent_sides))}

          true ->
            {:ok, :right}
        end

      with {:ok, next_side} <- next_side do
        finished_sides = Map.put(finished_sides, next_segment, next_side)
        set_segment_sides(segment_order, segment_graph, finished_sides, remaining_segments)
      end
    end
  end

  @spec build_segment_stops([Stop.t()], stick_side(), [stick_side()], [stick_side()], boolean()) ::
          [BranchStop.t()]
  defp build_segment_stops(
         segment_stops,
         segment_side,
         parent_sides,
         children_sides,
         has_segment_skipping
       ) do
    Enum.with_index(segment_stops, fn stop, stop_index ->
      is_first_stop = stop_index == 0
      is_last_stop = stop_index == length(segment_stops) - 1

      converging = is_first_stop and length(parent_sides) > 1
      diverging = is_last_stop and length(children_sides) > 1

      segment_side_state = %StickSideState{
        before: not is_first_stop or length(parent_sides) > 0,
        converging: converging,
        current_stop: true,
        diverging: diverging,
        after: not is_last_stop or length(children_sides) > 0
      }

      opposite_side_state = %StickSideState{
        before: (is_first_stop and length(parent_sides) == 2) or has_segment_skipping,
        converging: converging,
        current_stop: false,
        diverging: diverging,
        after:
          (is_last_stop and opposite_side(segment_side) in children_sides) or
            has_segment_skipping
      }

      states = %{
        segment_side => segment_side_state,
        opposite_side(segment_side) => opposite_side_state
      }

      %BranchStop{
        stop_id: stop.id,
        stick_state: %StickState{
          left: states[:left],
          right: states[:right]
        }
      }
    end)
  end

  @spec get_segment_name([Stop.t()], [String.t()]) :: String.t() | nil
  def get_segment_name(segment_stops, segment_name_candidates) do
    Enum.find(segment_name_candidates, fn candidate ->
      regex = ~r"(\b|^)#{candidate}(\b|$)"
      Enum.any?(segment_stops, &Regex.match?(regex, &1.name))
    end)
  end
end

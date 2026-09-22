defmodule MobileAppBackend.Alerts.AlertSummary.LineDigraph do
  require Logger
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache

  @spec build_stops_digraph_from_patterns([RoutePattern.t()], 0 | 1, GlobalDataCache.data()) ::
          :digraph.graph()
  def build_stops_digraph_from_patterns(patterns, direction_id, global) do
    digraph = :digraph.new([:acyclic, :protected])

    patterns
    |> Enum.filter(&(&1.direction_id == direction_id))
    |> Enum.map(&RoutePattern.get_child_stop_ids(&1, global))
    |> Enum.map(&Stop.get_parent_ids(&1, global))
    |> Enum.each(fn parent_stop_ids ->
      case parent_stop_ids do
        [parent_stop_id] ->
          :digraph.add_vertex(digraph, parent_stop_id)

        _ when length(parent_stop_ids) > 1 ->
          add_edges_and_vertices(digraph, parent_stop_ids)

        _ ->
          :ok
      end
    end)

    digraph
  end

  @spec add_edges_and_vertices(:digraph.graph(), [String.t()]) :: :ok
  defp add_edges_and_vertices(digraph, parent_stop_ids) do
    :digraph.add_vertex(digraph, List.first(parent_stop_ids))

    parent_stop_ids
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [prev, curr] ->
      :digraph.add_vertex(digraph, curr)
      :digraph.add_edge(digraph, prev, curr)
    end)

    :ok
  end

  @doc """
    Given a digraph and a target stop id, it will remove all stops that can not reach
    or can not be reached from the target stop.
  """
  @spec remove_unreachable_stops_from_digraph(:digraph.graph(), String.t()) ::
          :ok | {:error, :stop_not_found}
  def remove_unreachable_stops_from_digraph(digraph, target_stop) do
    case vertex_exists?(digraph, target_stop) do
      true ->
        all_reachable_stops = get_all_reachable_stops(digraph, target_stop)
        stops_to_remove = :digraph.vertices(digraph) -- all_reachable_stops

        if stops_to_remove != [] do
          :digraph.del_vertices(digraph, stops_to_remove)
        end

        :ok

      false ->
        {:error, :stop_not_found}
    end
  end

  @doc """
  Removes stops from the digraph that are not affected by the given list of affected stop IDs.
  """
  @spec remove_unaffected_stops(:digraph.graph(), %{RoutePattern.t() => [String.t()]}) ::
          :ok | {:error, :disconnected_stops}
  def remove_unaffected_stops(digraph, affected_pattern_stops) do
    affected_stops =
      affected_pattern_stops
      |> Enum.flat_map(fn {_pattern, stop_ids} -> stop_ids end)
      |> MapSet.new()

    stops_to_remove = :digraph.vertices(digraph) -- MapSet.to_list(affected_stops)

    if stops_to_remove != [] do
      :digraph.del_vertices(digraph, stops_to_remove)
    end

    if has_disconnected_stops?(digraph) do
      {:error, :disconnected_stops}
    else
      :ok
    end
  end

  @doc """
    From a diagraph get the first stops in which each stop represents a different branch
    of the same line, for example on the green line, Green B, Green C, Green D, and Green E
    have different first stops.
  """
  @spec get_first_stops(:digraph.graph(), GlobalDataCache.data()) :: [Stop.t()]
  def get_first_stops(digraph, global) do
    get_first_stop_ids(digraph)
    |> Enum.map(&global.stops[&1])
  end

  @spec get_first_stop_ids(:digraph.graph()) :: [:digraph.vertex()]
  def get_first_stop_ids(digraph) do
    :digraph.source_vertices(digraph)
  end

  @doc """
    From a diagraph get the last stops in which each stop represents a different branch
    of the same line, for example on the green line, Green B, Green C, Green D, and Green E
    have different last stops.
  """
  @spec get_last_stops(:digraph.graph(), GlobalDataCache.data()) :: [Stop.t()]
  def get_last_stops(digraph, global) do
    get_last_stop_ids(digraph)
    |> Enum.map(&global.stops[&1])
  end

  @spec get_last_stop_ids(:digraph.graph()) :: [:digraph.vertex()]
  def get_last_stop_ids(digraph) do
    :digraph.sink_vertices(digraph)
  end

  defp get_all_reachable_stops(digraph, target_stop) do
    reachable_stops = :digraph_utils.reachable([target_stop], digraph)
    reaching_stops = :digraph_utils.reaching([target_stop], digraph)

    MapSet.new(reachable_stops ++ reaching_stops)
    |> MapSet.to_list()
  end

  # Use for detecting disconnected source and sink stops in the digraph.
  # This would mean that after removing stops that are not affected
  # there were orphaned stops left in the digraph.
  @spec has_disconnected_stops?(:digraph.graph()) :: boolean()
  defp has_disconnected_stops?(digraph) do
    first_stops = get_first_stop_ids(digraph)
    last_stops = get_last_stop_ids(digraph)
    pairs = for x <- first_stops, y <- last_stops, x != y, do: {x, y}

    pairs
    |> Enum.reject(fn {first_stop, last_stop} ->
      if :digraph.get_path(digraph, first_stop, last_stop) do
        true
      else
        Logger.warning("Disconnected path from #{first_stop} to #{last_stop}")
        false
      end
    end)
    |> Enum.any?()
  end

  defp vertex_exists?(digraph, vertex) do
    match?({_vertex, _label}, :digraph.vertex(digraph, vertex))
  end
end

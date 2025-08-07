defmodule MobileAppBackend.RouteBranching do
  @moduledoc """
  Encapsulates the logic that turns A->B->D->E->F typical B->C->E atypical into

  ```text
     ┯  A
    ┌┷┐ B
  ® ┿ │ C
    │ ┿ D
    └┯┘ E
     ┷  F
  ```

  (although the actual Unicode graph rendering is in Mix.Tasks.CheckRouteBranching).

  A _segment_ in this context is a list of stops visited consecutively that are either all typical
  or all non-typical. A segment boundary is drawn where
  - stops change from typical to non-typical or non-typical to typical
  - there are multiple next stops
  - the next stop has multiple previous stops

  It is worth noting that a segment boundary is specifically not drawn if
  - stops change from one non-typical typicality to another
  - some trips are truncated versions of other similarly typical trips
  """

  require Logger
  alias MBTAV3API.Route
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.RouteBranching.Segment
  alias MobileAppBackend.RouteBranching.SegmentGraph
  alias MobileAppBackend.RouteBranching.StopDisambiguation
  alias MobileAppBackend.RouteBranching.StopGraph
  alias MobileAppBackend.RouteBranching.Workarounds

  @spec calculate(Route.id(), 0 | 1, [Stop.id()], GlobalDataCache.data()) ::
          {StopGraph.t(), SegmentGraph.t() | nil, [Segment.t()]}
  def calculate(route_id, direction_id, stop_ids, global_data) do
    context = %{route_id: route_id, direction_id: direction_id}
    stop_ids = Workarounds.rewrite_stop_ids(stop_ids, route_id, direction_id)
    route = global_data.routes[route_id]

    patterns =
      global_data.route_patterns
      |> Map.filter(fn {_, pattern} ->
        pattern.route_id == route_id and pattern.direction_id == direction_id
      end)
      |> Map.values()

    segment_name_candidates = get_name_candidates(route, direction_id)
    stop_disambiguation = StopDisambiguation.build(stop_ids, patterns, global_data)
    stop_graph = StopGraph.build(stop_disambiguation, global_data)

    segment_graph =
      if :digraph_utils.is_acyclic(stop_graph) do
        SegmentGraph.build(stop_graph)
      else
        unpeel_result({:error, "Stop graph contains cycle"}, context)
      end

    segment_order =
      if not is_nil(segment_graph) and :digraph_utils.is_acyclic(segment_graph) do
        get_segment_order(segment_graph, stop_ids)
      else
        if not is_nil(segment_graph) do
          unpeel_result({:error, "Segment graph contains cycle"}, context)
        end
      end

    segments =
      if not is_nil(segment_graph) and not is_nil(segment_order) do
        Segment.get_list_from_graph(
          segment_order,
          segment_graph,
          segment_name_candidates
        )
        |> unpeel_result(context)
      end

    segments = segments || Segment.get_fallback(stop_ids)

    {stop_graph, segment_graph, segments}
  end

  @spec unpeel_result({:ok, result} | {:error, String.t()}, map()) :: result | nil
        when result: var
  defp unpeel_result({:ok, result}, _), do: result

  defp unpeel_result({:error, error}, context) do
    Logger.error("in context #{inspect(context)}: #{error}")

    Sentry.capture_message(error, request: context)

    nil
  end

  # the index of a segment in the canon stop list is the number of stops from the canon list that would need to be
  # deleted before the segment starts. unfortunately, we need to break ties topologically, rather than in a way
  # that’s easy to determine a priori, so it’s actually a topological sort with ties broken by index in the canon
  # stop list
  @spec get_segment_order(SegmentGraph.t(), [Stop.id()]) :: [SegmentGraph.vertex_id()]
  defp get_segment_order(segment_graph, stop_ids) do
    segment_canon_indices =
      Map.new(:digraph.vertices(segment_graph), fn segment_id ->
        {_, segment} = :digraph.vertex(segment_graph, segment_id)
        segment_stop_ids = Enum.map(segment.stops, & &1.id)

        segment_index_into_stop_ids =
          List.myers_difference(stop_ids, segment_stop_ids)
          |> Enum.take_while(fn {action, _} -> action != :eq end)
          |> Enum.sum_by(fn
            {:del, sublist} -> length(sublist)
            {:ins, _} -> 0
          end)

        {segment_id, segment_index_into_stop_ids}
      end)

    sources =
      :digraph.vertices(segment_graph)
      |> Enum.filter(&(:digraph.in_degree(segment_graph, &1) == 0))
      |> MapSet.new()

    segment_topo_index_sort(sources, segment_graph, segment_canon_indices)
  end

  @spec segment_topo_index_sort(
          MapSet.t(SegmentGraph.vertex_id()),
          SegmentGraph.t(),
          %{SegmentGraph.vertex_id() => non_neg_integer()},
          [SegmentGraph.vertex_id()]
        ) :: [SegmentGraph.vertex_id()]
  defp segment_topo_index_sort(frontier, segment_graph, canon_indices, result \\ []) do
    if Enum.empty?(frontier) do
      Enum.reverse(result)
    else
      # anything in the frontier that has a parent still in the frontier is not ready even if its index is lower
      frontier_ready =
        MapSet.reject(frontier, fn vertex ->
          Enum.any?(:digraph.in_neighbours(segment_graph, vertex), &MapSet.member?(frontier, &1))
        end)

      next_segment = Enum.min_by(frontier_ready, &canon_indices[&1])
      next_neighbors = :digraph.out_neighbours(segment_graph, next_segment) |> MapSet.new()
      frontier = frontier |> MapSet.union(next_neighbors) |> MapSet.delete(next_segment)
      segment_topo_index_sort(frontier, segment_graph, canon_indices, [next_segment | result])
    end
  end

  @doc """
  Branch names can come from route names (the “Providence/Stoughton Line” implies that a Providence branch and a Stoughton branch may exist) or from direction destinations (“Ashmont/Braintree” implies that an Ashmont branch and a Braintree branch may exist, and “Foxboro or Providence” implies that a Foxboro branch and a Providence branch may exist).

  Branch names are only calculated for subway and commuter rail routes, because they are much less useful on ferry (where branches only have one or two stops) and bus (where service patterns may vary widely).
  """
  def get_name_candidates(route, direction_id) do
    if route.type in [:light_rail, :heavy_rail, :commuter_rail] do
      branching_route_regex = ~r"^([\w\s]+)/([\w\s]+) Line$"
      line = Regex.run(branching_route_regex, route.long_name, capture: :all_but_first) || []
      branching_direction_regexes = [~r"([\w\s]+)/([\w\s]+)", ~r"([\w\s]+) or ([\w\s]+)"]

      this_direction =
        Enum.find_value(
          branching_direction_regexes,
          [],
          &Regex.run(&1, Enum.at(route.direction_destinations, direction_id),
            capture: :all_but_first
          )
        )

      opposite_direction =
        Enum.find_value(
          branching_direction_regexes,
          [],
          &Regex.run(&1, Enum.at(route.direction_destinations, 1 - direction_id),
            capture: :all_but_first
          )
        )

      line ++ this_direction ++ opposite_direction
    else
      []
    end
  end
end

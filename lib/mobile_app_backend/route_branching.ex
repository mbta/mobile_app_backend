defmodule MobileAppBackend.RouteBranching do
  @moduledoc """
  Encapsulates the logic that turns A->B->D->E->F typical B->C->E atypical into

  ```text
     ┯  A
    ┌┷┐ B
  ® │ ┿ C
    ┿ │ D
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
  alias MobileAppBackend.RouteBranching.StopGraph
  alias MobileAppBackend.RouteBranching.Workarounds

  @spec calculate(Route.id(), 0 | 1, [Stop.id()], GlobalDataCache.data()) ::
          {StopGraph.t(), SegmentGraph.t() | nil, [Segment.t()] | nil}
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
    stop_graph = StopGraph.build(route_id, direction_id, stop_ids, patterns, global_data)

    segment_graph =
      if :digraph_utils.is_acyclic(stop_graph) do
        SegmentGraph.build(stop_graph)
      else
        unpeel_result({:error, "Stop graph contains cycle"}, context)
      end

    segment_order =
      if not is_nil(segment_graph) and :digraph_utils.is_acyclic(segment_graph) do
        get_segment_order(segment_graph, stop_ids, global_data)
        |> unpeel_result(context)
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

    {stop_graph, segment_graph, segments}
  end

  @spec unpeel_result({:ok, result} | {:error, String.t()}, map()) :: result | nil
        when result: var
  defp unpeel_result({:ok, result}, _), do: result

  defp unpeel_result({:error, error}, context) do
    Logger.error(error)

    Sentry.capture_message(error, request: context)

    nil
  end

  @spec get_segment_order(SegmentGraph.t(), [Stop.id()], GlobalDataCache.data()) ::
          {:ok, [SegmentGraph.vertex_id()]} | {:error, String.t()}
  defp get_segment_order(segment_graph, stop_ids, global_data) do
    result =
      stop_ids
      |> Enum.map(fn stop_id ->
        stop = global_data.stops[stop_id]

        [stop_id | stop.child_stop_ids]
        |> Enum.map(&{&1, 1})
        |> Enum.find(&(:digraph.vertex(segment_graph, &1) != false))
      end)
      |> Enum.reject(&is_nil/1)

    if length(result) == :digraph.no_vertices(segment_graph) do
      {:ok, result}
    else
      {:error,
       "#{:digraph.no_vertices(segment_graph) - length(result)} segments lost, presumably with count greater than 1"}
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

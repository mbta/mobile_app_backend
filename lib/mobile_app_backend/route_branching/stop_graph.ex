defmodule MobileAppBackend.RouteBranching.StopGraph do
  @moduledoc """
  Records the connections between individual stops, preserving how typical stops are.
  """
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.RouteBranching.GraphUtil
  alias MobileAppBackend.RouteBranching.Workarounds

  defmodule Node do
    alias MBTAV3API.RoutePattern
    @type t :: %__MODULE__{stop: Stop.t(), typicalities: MapSet.t(RoutePattern.typicality())}
    defstruct [:stop, :typicalities]
  end

  @type t :: :digraph.graph()
  @typedoc """
  A stop ID and and a count of how many times this stop has appeared.
  For looping routes, the first copy of a stop will be {"foo", 1} and the second {"foo", 2}.
  """
  @type vertex_id :: {Stop.id(), count :: pos_integer()}
  @type edge_id :: {vertex_id(), vertex_id()}

  @spec build(Route.id(), 0 | 1, [Stop.id()], [RoutePattern.t()], GlobalDataCache.data()) :: t()
  def build(route_id, direction_id, stop_ids, patterns, global_data) do
    canon_stops = MapSet.new(stop_ids)

    result = :digraph.new([:cyclic, :protected])

    typicalities_stops_with_counts =
      Enum.map(patterns, &pattern_typicality_stops(&1, canon_stops, global_data))

    typicalities_stops_with_counts
    |> Enum.flat_map(fn {t, stops_with_counts} -> Enum.map(stops_with_counts, &{t, &1}) end)
    |> Enum.group_by(fn {_t, stop_with_count} -> stop_with_count end, fn {t, _stop_with_count} ->
      t
    end)
    |> Enum.each(fn {{stop_id, stop_count}, typicalities} ->
      :digraph.add_vertex(result, {stop_id, stop_count}, %Node{
        stop: global_data.stops[stop_id],
        typicalities: MapSet.new(typicalities)
      })
    end)

    for {_, stops_with_counts} <- typicalities_stops_with_counts do
      for [from, to] <- Enum.chunk_every(stops_with_counts, 2, 1, :discard) do
        :digraph.add_edge(result, {from, to}, from, to, nil)
      end
    end

    Workarounds.rewrite_stop_graph(result, route_id, direction_id)
    GraphUtil.drop_skipping_edges(result)

    result
  end

  @spec pattern_typicality_stops(RoutePattern.t(), MapSet.t(Stop.id()), GlobalDataCache.data()) ::
          {RoutePattern.typicality(), [{Stop.id(), pos_integer()}]}
  defp pattern_typicality_stops(pattern, canon_stops, global_data) do
    trip = global_data.trips[pattern.representative_trip_id]

    stops_with_counts =
      trip.stop_ids
      |> Enum.map(&stop_or_parent_if_canon(&1, canon_stops, global_data))
      |> Enum.reject(&is_nil/1)
      |> stops_with_counts()

    {pattern.typicality, stops_with_counts}
  end

  @spec stop_or_parent_if_canon(Stop.id(), MapSet.t(Stop.id()), GlobalDataCache.data()) ::
          Stop.id() | nil
  defp stop_or_parent_if_canon(stop_id, canon_stops, global_data) do
    if MapSet.member?(canon_stops, stop_id) do
      stop_id
    else
      parent = global_data.stops[stop_id].parent_station_id

      if MapSet.member?(canon_stops, parent) do
        parent
      end
    end
  end

  @spec stops_with_counts([Stop.id()], %{Stop.id() => pos_integer()}, [{Stop.id(), pos_integer()}]) ::
          [{Stop.id(), pos_integer()}]
  defp stops_with_counts(stop_ids, counts \\ %{}, result \\ [])

  defp stops_with_counts([], _, result), do: Enum.reverse(result)

  defp stops_with_counts([stop_id | stop_ids], counts, result) do
    {count, counts} =
      Map.get_and_update(counts, stop_id, fn
        nil -> {1, 1}
        x -> {x + 1, x + 1}
      end)

    stops_with_counts(stop_ids, counts, [{stop_id, count} | result])
  end
end

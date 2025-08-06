defmodule MobileAppBackend.RouteBranching.StopGraph do
  @moduledoc """
  Records the connections between individual stops, preserving how typical stops are.
  """
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.RouteBranching.GraphUtil
  alias MobileAppBackend.RouteBranching.StopDisambiguation

  defmodule Node do
    alias MBTAV3API.RoutePattern
    @type t :: %__MODULE__{stop: Stop.t(), typicalities: MapSet.t(RoutePattern.typicality())}
    defstruct [:stop, :typicalities]
  end

  @type t :: :digraph.graph()
  @typedoc """
  A stop ID and and a count of how many times this stop has appeared.
  For looping routes, the first copy of a stop will be {"foo", 1} and the second {"foo", 2}.
  For routes which only sometimes loop, the more typical patterns get dibs on the lower numbers,
  and then with the power of `List.myers_difference/2` we figure out which copy of the stop is the
  one that already exists with count 1 and which one is the new one that needs count 2.
  """
  @type vertex_id :: {Stop.id(), count :: pos_integer()}
  @type edge_id :: {vertex_id(), vertex_id()}

  @spec build(StopDisambiguation.t(), GlobalDataCache.data()) :: t()
  def build(patterns_disambiguated_stops, global_data) do
    result = :digraph.new([:cyclic, :protected])

    patterns_disambiguated_stops
    |> Enum.flat_map(fn {pattern, disambiguated_stops} ->
      Enum.map(disambiguated_stops, &{pattern.typicality, &1})
    end)
    |> Enum.group_by(
      fn {_t, disambiguated_stop} -> disambiguated_stop end,
      fn {t, _disambiguated_stop} -> t end
    )
    |> Enum.each(fn {{stop_id, stop_count}, typicalities} ->
      :digraph.add_vertex(result, {stop_id, stop_count}, %Node{
        stop: global_data.stops[stop_id],
        typicalities: MapSet.new(typicalities)
      })
    end)

    for {_, stops_with_counts} <- patterns_disambiguated_stops do
      for [from, to] <- Enum.chunk_every(stops_with_counts, 2, 1, :discard) do
        :digraph.add_edge(result, {from, to}, from, to, nil)
      end
    end

    GraphUtil.drop_skipping_edges(result)

    result
  end
end

defmodule MobileAppBackend.RouteBranching.Workarounds do
  alias MBTAV3API.Route
  alias MBTAV3API.Stop
  alias MobileAppBackend.RouteBranching.StopGraph

  @doc """
  Rewrites a list of stop IDs as returned by the V3 API to apply the necessary workarounds.
  """
  @spec rewrite_stop_ids([Stop.id()], Route.id(), 0 | 1) :: [Stop.id()]
  def rewrite_stop_ids(stop_ids, route_id, direction_id)

  # as of 2025-07-21, the 33 inbound has typical B->C atypical A->C A->D B->D, but the stop IDs are ADBC
  # with minor Elixir crimes we can use pure pattern matching in a legible way to solve this
  special_case_33_inbound_a = [
    "18975",
    "8328",
    "8329",
    "8330",
    "8331",
    "8332",
    "8333",
    "42820",
    "8335"
  ]

  special_case_33_inbound_bc = [
    "18974",
    "6512",
    "6513",
    "6514",
    "6515",
    "6516",
    "6517",
    "6519",
    "6522",
    "6523",
    "6524",
    "6526",
    "6527",
    "6528",
    "6529"
  ]

  special_case_33_inbound_d = ["8337", "8343", "8344"]

  def rewrite_stop_ids(
        [
          unquote_splicing(special_case_33_inbound_a),
          unquote_splicing(special_case_33_inbound_d),
          unquote_splicing(special_case_33_inbound_bc) | rest
        ],
        "33",
        1
      ) do
    record_workaround_used("33", 1)

    [
      unquote_splicing(special_case_33_inbound_a),
      unquote_splicing(special_case_33_inbound_bc),
      unquote_splicing(special_case_33_inbound_d) | rest
    ]
  end

  def rewrite_stop_ids(stop_ids, _, _), do: stop_ids

  @spec rewrite_stop_graph(StopGraph.t(), Route.id(), 0 | 1) :: :ok
  def rewrite_stop_graph(stop_graph, route_id, direction_id)

  def rewrite_stop_graph(stop_graph, "70", 0) do
    # as of 2025-07-14 the 70 outbound has A->B typical B->A deviation, so drop the deviation B->A
    a = {"88333", 1}
    b = {"883321", 1}

    if contains_all_edges(stop_graph, [{a, b}, {b, a}]) do
      record_workaround_used("70", 0)

      :digraph.del_edge(stop_graph, {b, a})
    end

    :ok
  end

  def rewrite_stop_graph(stop_graph, "Boat-F6", 1) do
    # as of 2025-07-14 morning routes visit Logan only after Seaport/Fan and afternoon routes visit Logan only before
    # Central Wharf so Logan never gets disambiguated
    a = {"Boat-Winthrop", 1}
    b = {"Boat-Logan", 1}
    c = {"Boat-Aquarium", 1}
    d = {"Boat-Fan", 1}
    e = {"Boat-Logan", 2}
    f = {"Boat-Winthrop", 2}

    if stop_graph |> :digraph.vertices() |> Enum.sort() == Enum.sort([a, b, c, d, f]) do
      record_workaround_used("Boat-F6", 1)

      {^b, node_value} = :digraph.vertex(stop_graph, b)

      :digraph.add_vertex(stop_graph, e, node_value)
      :digraph.add_edge(stop_graph, {d, e}, d, e, nil)
      :digraph.add_edge(stop_graph, {e, f}, e, f, nil)
      :digraph.del_edges(stop_graph, [{d, b}, {b, f}, {b, a}])
    end

    :ok
  end

  def rewrite_stop_graph(stop_graph, "Boat-F7", 1) do
    # as of 2025-07-14morning routes visit Logan only after Central Wharf and afternoon routes visit Logan only before
    # Seaport/Fan so Logan never gets disambiguated
    a = {"Boat-Quincy", 1}
    b = {"Boat-Logan", 1}
    c = {"Boat-Fan", 1}
    d = {"Boat-Aquarium", 1}
    e = {"Boat-Logan", 2}
    f = {"Boat-Quincy", 2}

    if stop_graph |> :digraph.vertices() |> Enum.sort() == Enum.sort([a, b, c, d, f]) do
      record_workaround_used("Boat-F7", 1)

      {^b, node_value} = :digraph.vertex(stop_graph, b)

      :digraph.add_vertex(stop_graph, e, node_value)
      :digraph.add_edge(stop_graph, {d, e}, d, e, nil)
      :digraph.add_edge(stop_graph, {e, f}, e, f, nil)
      :digraph.del_edges(stop_graph, [{d, b}, {b, f}, {b, a}])
    end

    :ok
  end

  def rewrite_stop_graph(_, _, _), do: :ok

  defp contains_all_edges(stop_graph, edges) do
    Enum.all?(edges, fn {from, to} -> :digraph.edge(stop_graph, {from, to}) != false end)
  end

  # Used by check_route_branching to verify that no workarounds have gone stale.
  # Always call with literals so that check_route_branching can determine that the workaround exists.
  defp record_workaround_used(route_id, direction_id) do
    :telemetry.execute([__MODULE__, :used], %{}, %{route_id: route_id, direction_id: direction_id})
  end
end

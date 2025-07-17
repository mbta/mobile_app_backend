defmodule MobileAppBackend.RouteBranching.Workarounds do
  alias MBTAV3API.Route
  alias MBTAV3API.Stop
  alias MobileAppBackend.RouteBranching.StopGraph

  @doc """
  Rewrites a list of stop IDs as returned by the V3 API to apply the necessary workarounds.
  """
  @spec rewrite_stop_ids([Stop.id()], Route.id(), 0 | 1) :: [Stop.id()]
  def rewrite_stop_ids(stop_ids, route_id, direction_id)

  # as of 2025-07-11, the 64 outbound has an A->C->E B->C->E D->E, which would be manageable if the RouteStopsResult
  # said ABCDE, but it says DABCE, causing three parallel segments.
  # with minor Elixir crimes we can use pure pattern matching in a legible way to solve this
  special_case_64_outbound_abc = ["730", "2755", "1060", "72", "1123"]

  special_case_64_outbound_d = [
    "2231",
    "12232",
    "24486",
    "24487",
    "24488",
    "24489",
    "2442",
    "2443"
  ]

  special_case_64_outbound_e = ["2444"]

  def rewrite_stop_ids(
        [
          unquote_splicing(special_case_64_outbound_d),
          unquote_splicing(special_case_64_outbound_abc),
          unquote_splicing(special_case_64_outbound_e) | rest
        ],
        "64",
        0
      ) do
    record_workaround_used("64", 0)

    [
      unquote_splicing(special_case_64_outbound_abc),
      unquote_splicing(special_case_64_outbound_d),
      unquote_splicing(special_case_64_outbound_e) | rest
    ]
  end

  def rewrite_stop_ids(stop_ids, _, _), do: stop_ids

  @spec rewrite_stop_graph(StopGraph.t(), Route.id(), 0 | 1) :: :ok
  def rewrite_stop_graph(stop_graph, route_id, direction_id)

  def rewrite_stop_graph(stop_graph, "33", 0) do
    # as of 2025-07-11 the 33 outbound has A->C B->C B->D, and that’s not technically three parallel segments, but it
    # is three parallel lines, which is not better for us, so drop the atypical A->C
    a = {"89414", 1}
    b = {"8955", 1}
    c = {"89413", 1}
    d = {"8970", 1}

    if contains_all_edges(stop_graph, [{a, c}, {b, c}, {b, d}]) do
      record_workaround_used("33", 0)

      :digraph.del_edge(stop_graph, {a, c})
    end

    :ok
  end

  def rewrite_stop_graph(stop_graph, "33", 1) do
    # as of 2025-07-14 the 33 inbound has A->C A->D B->C B->D, and A->D and B->D are atypical but the RouteStopsResult
    # says ADBC so we erase the deviation A->C and the atypical B->D
    a = {"8335", 1}
    b = {"6515", 1}
    c = {"6516", 1}
    d = {"8337", 1}

    if contains_all_edges(stop_graph, [{a, c}, {a, d}, {b, c}, {b, d}]) do
      record_workaround_used("33", 1)

      :digraph.del_edges(stop_graph, [{a, c}, {b, d}])
    end

    :ok
  end

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

  def rewrite_stop_graph(stop_graph, "238", 0) do
    # as of 2025-07-14 the 238 outbound has A->B->... typical A->C deviation A->D->... atypical so connect C->D
    a = {"4058", 1}
    b = {"4252", 1}
    c = {"4277", 1}
    d = {"4214", 1}

    if contains_all_edges(stop_graph, [{a, b}, {a, c}, {a, d}]) do
      record_workaround_used("238", 0)

      :digraph.add_edge(stop_graph, {c, d}, c, d, nil)
    end

    :ok
  end

  def rewrite_stop_graph(stop_graph, "350", 0) do
    # as of 2025-07-14 the 350 outbound has A->...->B->C->...->F B->D A->...->E->F, so connect D->C
    b = {"50940", 1}
    c = {"49807", 1}
    d = {"49805", 1}
    e = {"1691", 1}
    f = {"1692", 1}

    if contains_all_edges(stop_graph, [{b, c}, {b, d}, {e, f}]) do
      record_workaround_used("350", 0)

      :digraph.add_edge(stop_graph, {d, c}, d, c, nil)
    end

    :ok
  end

  def rewrite_stop_graph(stop_graph, "Boat-F1", 1) do
    # as of 2025-07-14 the Hingham/Hull Ferry inbound has atypical A->B typical A->C A->D and the stop ID list has
    # ACBD so connect C->B
    a = {"Boat-Hingham", 1}
    b = {"Boat-George", 1}
    c = {"Boat-Rowes", 1}
    d = {"Boat-Hull", 1}

    if contains_all_edges(stop_graph, [{a, b}, {a, c}, {a, d}]) do
      record_workaround_used("Boat-F1", 1)

      :digraph.add_edge(stop_graph, {c, b}, c, b, nil)
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

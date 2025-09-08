defmodule MobileAppBackend.RouteBranching.Workarounds do
  alias MBTAV3API.Route
  alias MBTAV3API.Stop

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

  # Used by check_route_branching to verify that no workarounds have gone stale.
  # Always call with literals so that check_route_branching can determine that the workaround exists.
  defp record_workaround_used(route_id, direction_id) do
    :telemetry.execute([__MODULE__, :used], %{}, %{route_id: route_id, direction_id: direction_id})
  end
end

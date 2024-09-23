defmodule MobileAppBackend.GlobalDataCache do
  use GenServer
  alias MBTAV3API.{JsonApi, Repository}
  alias MBTAV3API.JsonApi.Object

  @typedoc """
  A key to disambiguate other persistent_term entries from the one owned by this cache instance.
  Defaults to the module name.
  """
  @type key :: term()

  @type data :: %{
          lines: Object.line_map(),
          pattern_ids_by_stop: %{
            (stop_id :: String.t()) => route_pattern_ids :: [String.t()]
          },
          routes: Object.route_map(),
          route_patterns: Object.route_pattern_map(),
          stops: Object.stop_map(),
          trips: Object.trip_map()
        }

  defmodule State do
    defstruct [:key, :update_ms]
  end

  def default_key, do: __MODULE__

  def start_link(opts) do
    opts = Keyword.merge([key: default_key()], opts)
    GenServer.start_link(__MODULE__, opts)
  end

  @spec get_data(key()) :: data()
  def get_data(key \\ default_key()) do
    :persistent_term.get(key, nil) || update_data(key)
  end

  @impl GenServer
  def init(opts) do
    opts = Keyword.merge(Application.get_env(:mobile_app_backend, __MODULE__), opts)

    state = %State{
      key: opts[:key],
      update_ms: opts[:update_ms] || :timer.minutes(5)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:recalculate, %State{} = state) do
    update_data(state.key)

    Process.send_after(self(), :recalculate, state.update_ms)

    {:noreply, state}
  end

  @spec update_data(key()) :: data()
  defp update_data(key) do
    stops = fetch_stops()

    %{
      lines: lines,
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    } = fetch_route_patterns()

    data = %{
      lines: lines,
      pattern_ids_by_stop: pattern_ids_by_stop,
      routes: routes,
      route_patterns: route_patterns,
      stops: stops,
      trips: trips
    }

    :persistent_term.put(key, data)

    data
  end

  @spec fetch_stops() :: JsonApi.Object.stop_map()
  defp fetch_stops do
    {:ok, %{data: stops}} =
      Repository.stops(
        filter: [
          location_type: [:stop, :station]
        ],
        include: [:child_stops, :connecting_stops, :parent_station]
      )

    Map.new(stops, &{&1.id, &1})
  end

  @spec fetch_route_patterns() :: %{
          lines: JsonApi.Object.line_map(),
          routes: JsonApi.Object.route_map(),
          route_patterns: JsonApi.Object.route_pattern_map(),
          trips: JsonApi.Object.trip_map(),
          pattern_ids_by_stop: %{(stop_id :: String.t()) => route_pattern_ids :: [String.t()]}
        }
  defp fetch_route_patterns do
    {:ok, %{data: route_patterns, included: %{lines: lines, routes: routes, trips: trips}}} =
      Repository.route_patterns(
        include: [route: :line, representative_trip: :stops],
        fields: [stop: []]
      )

    pattern_ids_by_stop = MBTAV3API.RoutePattern.get_pattern_ids_by_stop(route_patterns, trips)

    trips = Map.new(trips, fn {trip_id, trip} -> {trip_id, trip} end)

    route_patterns = Map.new(route_patterns, &{&1.id, &1})

    %{
      lines: lines,
      routes: routes,
      route_patterns: route_patterns,
      trips: trips,
      pattern_ids_by_stop: pattern_ids_by_stop
    }
  end
end

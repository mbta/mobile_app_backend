defmodule MobileAppBackend.Alerts.PubSub.Behaviour do
  alias MBTAV3API.Alert

  @doc """
  Subscribe to updates for all alerts
  """
  @callback subscribe(legacy_compatibility: boolean()) :: %{alerts: %{Alert.id() => Alert.t()}}
end

defmodule MobileAppBackend.Alerts.PubSub do
  @moduledoc """
  Allows channels to subscribe to alerts data and receive updates as the data changes.

  This broadcasts the latest state of the world (if it has changed) to
  registered consumers in two circumstances:
  1. Regularly scheduled interval - configured by `:alerts_broadcast_interval_ms`
  2. When there is a reset event of the underlying alert stream.
  """
  use MobileAppBackend.PubSub,
    broadcast_interval_ms:
      Application.compile_env(:mobile_app_backend, :alerts_broadcast_interval_ms, 500)

  alias MBTAV3API.Alert
  alias MBTAV3API.Store
  alias MBTAV3API.Stream
  alias MobileAppBackend.Alerts.PubSub

  @behaviour PubSub.Behaviour

  @fetch_registry_key :fetch_registry_key

  @type state :: %{last_dispatched_table_name: atom()}

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  @spec start_link() :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(
      __MODULE__,
      opts,
      name: name
    )
  end

  @doc """
  The legacy alert channel needs to filter out any references to new alert causes,
  they will break old versions of the app entirely if they're sent to the frontend.
  """
  @spec map_data([Alert.t()], boolean()) :: %{Alert.id() => Alert.t()}
  # https://github.com/elixir-lang/elixir/issues/14837#issuecomment-3419664245
  # this was still not resolved as of elixir 1.21.2
  @dialyzer {:no_opaque, map_data: 2}
  def map_data(data, legacy_compatibility) do
    legacy_map = fn %Alert{} = alert ->
      if MapSet.member?(Alert.v2_causes(), alert.cause),
        do: %Alert{alert | cause: :unknown_cause},
        else: alert
    end

    if legacy_compatibility do
      data |> Enum.map(legacy_map)
    else
      data
    end
    |> Map.new(fn alert -> {alert.id, alert} end)
  end

  @impl true
  def subscribe(opts \\ []) do
    fetch_keys = []

    format_fn = fn data ->
      %{
        alerts:
          data
          |> map_data(Keyword.get(opts, :legacy_compatibility, true))
          |> filter_upcoming_single_tracking_alerts()
      }
    end

    Registry.register(
      MobileAppBackend.Alerts.Registry,
      @fetch_registry_key,
      {fetch_keys, format_fn}
    )

    fetch_keys
    |> Store.Alerts.fetch()
    |> format_fn.()
  end

  # Temporary patch because upcoming single tracking alerts are displayed
  # incorrectly in the app. Remove any single tracking alerts that aren't happening
  # right now.
  defp filter_upcoming_single_tracking_alerts(alerts) do
    Map.filter(alerts, fn {_key, alert} ->
      !(alert.cause == :single_tracking && !Alert.active?(alert))
    end)
  end

  @impl GenServer
  def init(opts \\ []) do
    Stream.StaticInstance.subscribe("alerts:to_store")
    broadcast_initial_timer()

    create_table_fn =
      Keyword.get(opts, :create_table_fn, fn ->
        :ets.new(:last_dispatched_alerts, [:set, :named_table])
        {:ok, %{last_dispatched_table_name: :last_dispatched_alerts}}
      end)

    create_table_fn.()
  end

  @impl GenServer
  def handle_info(:broadcast, %{last_dispatched_table_name: last_dispatched} = state) do
    Registry.dispatch(MobileAppBackend.Alerts.Registry, @fetch_registry_key, fn entries ->
      entries
      |> MobileAppBackend.PubSub.group_pids_by_target_data()
      |> Enum.each(fn {{fetch_keys, format_fn} = registry_value, pids} ->
        fetch_keys
        |> Store.Alerts.fetch()
        |> format_fn.()
        |> MobileAppBackend.PubSub.broadcast_latest_data(
          :new_alerts,
          registry_value,
          pids,
          last_dispatched
        )
      end)
    end)

    {:noreply, state, :hibernate}
  end
end

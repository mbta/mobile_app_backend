defmodule MobileAppBackend.Alerts.WithSummaryPubSub.Behaviour do
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertWithSummaries

  @doc """
  Subscribe to updates for all alerts
  """
  @callback subscribe(locale: String.t()) ::
              %{alerts_with_summaries: %{Alert.id() => AlertWithSummaries.t()}}
end

defmodule MobileAppBackend.Alerts.WithSummaryPubSub do
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
  alias MobileAppBackend.Alerts
  alias MobileAppBackend.Alerts.AlertWithSummaries
  alias MobileAppBackend.Alerts.SummaryEntityBuilder

  @behaviour __MODULE__.Behaviour

  @default_locale MobileAppBackend.Application.default_locale()
  @default_ets_table :last_dispatched_alerts_with_summary
  @fetch_registry_key :fetch_registry_key_with_summary

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

  @impl true
  def subscribe(opts \\ []) do
    locale = Keyword.get(opts, :locale, @default_locale)

    fetch_keys = []

    format_fn = fn data ->
      %{
        alerts_with_summaries:
          data
          |> Map.get({locale, :card}, %{})
          |> filter_upcoming_single_tracking_alerts()
      }
    end

    Registry.register(
      MobileAppBackend.Alerts.Registry,
      @fetch_registry_key,
      {fetch_keys, format_fn}
    )

    # we don’t want to bottleneck subscribe/1 calls in the server process,
    # so we can’t read this from the state. conveniently it’s only overridden in tests
    ets_table = Keyword.get(opts, :ets_table, @default_ets_table)

    all_summaries =
      case :ets.lookup(ets_table, :all_summaries) do
        [{:all_summaries, all_summaries}] -> all_summaries
        [] -> %{}
      end

    format_fn.(all_summaries)
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
    upstream = Application.get_env(:mobile_app_backend, Alerts.PubSub, Alerts.PubSub)

    upstream.subscribe(legacy_compatibility: false)
    broadcast_timer(50)

    create_table_fn =
      Keyword.get(opts, :create_table_fn, fn ->
        :ets.new(@default_ets_table, [:set, :named_table])
        {:ok, %{last_dispatched_table_name: @default_ets_table}}
      end)

    create_table_fn.()
  end

  @impl GenServer
  def handle_info(:broadcast, %{last_dispatched_table_name: last_dispatched} = state) do
    all_summaries = recalculate(last_dispatched)

    perform_broadcast(last_dispatched, all_summaries)

    {:noreply, state, :hibernate}
  end

  def handle_info(
        {:new_alerts, %{alerts: all_alerts}},
        %{last_dispatched_table_name: last_dispatched} = state
      ) do
    all_summaries = recalculate(last_dispatched, Map.values(all_alerts))
    perform_broadcast(last_dispatched, all_summaries)
    {:noreply, state}
  end

  defp perform_broadcast(last_dispatched, all_summaries) do
    Registry.dispatch(MobileAppBackend.Alerts.Registry, @fetch_registry_key, fn entries ->
      entries
      |> MobileAppBackend.PubSub.group_pids_by_target_data()
      |> Enum.each(fn {{_fetch_keys, format_fn} = registry_value, pids} ->
        all_summaries
        |> format_fn.()
        |> MobileAppBackend.PubSub.broadcast_latest_data(
          :new_alerts,
          registry_value,
          pids,
          last_dispatched
        )
      end)
    end)
  end

  @typep alerts_with_summaries :: %{Alert.id() => AlertWithSummaries.t()}
  @typep summary_key :: {locale :: String.t(), :notification | :card}
  @typep all_summaries :: %{summary_key() => alerts_with_summaries()}

  defp recalculate(ets_table, all_alerts \\ nil) do
    all_alerts = all_alerts || Store.Alerts.fetch([])
    all_summaries = build_all_summaries(all_alerts)
    :ets.insert(ets_table, {:all_summaries, all_summaries})
    all_summaries
  end

  @spec build_all_summaries([Alert.t()]) :: all_summaries()
  defp build_all_summaries(alerts) do
    alerts_by_id = Map.new(alerts, &{&1.id, &1})

    for locale <- Application.get_env(:mobile_app_backend, :locale_codes),
        context <- [:notification, :card],
        into: %{} do
      alerts_with_summaries =
        SummaryEntityBuilder.build_all(alerts, locale, context)
        |> Map.new(fn {alert_id, summary_entities} ->
          alert = alerts_by_id[alert_id]
          value = AlertWithSummaries.from_alert(alert, summary_entities)
          {alert_id, value}
        end)

      {{locale, context}, alerts_with_summaries}
    end
  end
end

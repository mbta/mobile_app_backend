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
  1. Regularly scheduled interval - configured by
  `:alerts_with_summaries_broadcast_interval_ms`
  2. When there is a reset event of the underlying alert stream.
  """
  use MobileAppBackend.PubSub,
    broadcast_interval_ms:
      Application.compile_env(
        :mobile_app_backend,
        :alerts_with_summaries_broadcast_interval_ms,
        60_000
      )

  alias MBTAV3API.Alert
  alias MBTAV3API.Store
  alias MobileAppBackend.Alerts
  alias MobileAppBackend.Alerts.AlertWithSummaries
  alias MobileAppBackend.Alerts.SummaryEntityBuilder

  require Logger

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
          |> Map.get(locale, %{})
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
    broadcast_initial_timer()

    create_table_fn =
      Keyword.get(opts, :create_table_fn, fn ->
        :ets.new(@default_ets_table, [:set, :named_table])
        {:ok, %{last_dispatched_table_name: @default_ets_table}}
      end)

    create_table_fn.()
  end

  @impl GenServer
  def handle_info(:broadcast, %{last_dispatched_table_name: last_dispatched} = state) do
    Logger.info("#{__MODULE__} handle :broadcast started")
    now = Map.get(state, :now, DateTime.now!("America/New_York"))

    {time_micros, _results} =
      :timer.tc(fn ->
        all_summaries = recalculate(last_dispatched, now)

        perform_broadcast(last_dispatched, all_summaries)
      end)

    time_ms = time_micros / 1000

    Logger.info("#{__MODULE__} handle :broadcast completed duration=#{time_ms}")
    {:noreply, state, :hibernate}
  end

  def handle_info(
        {:new_alerts, %{alerts: all_alerts}},
        %{last_dispatched_table_name: last_dispatched} = state
      ) do
    Logger.info("#{__MODULE__} handle :new_alerts started")
    now = Map.get(state, :now, DateTime.now!("America/New_York"))

    {time_micros, _results} =
      :timer.tc(fn ->
        all_summaries = recalculate(last_dispatched, now, Map.values(all_alerts))

        perform_broadcast(last_dispatched, all_summaries)
      end)

    time_ms = time_micros / 1000
    Logger.info("#{__MODULE__} handle :new_alerts completed duration=#{time_ms}")

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
  @typep summary_key :: locale :: String.t()
  @typep all_summaries :: %{summary_key() => alerts_with_summaries()}

  defp recalculate(ets_table, now, all_alerts \\ nil) do
    old_summaries_by_locale =
      case :ets.lookup(ets_table, :all_summaries) do
        [{:all_summaries, all_summaries}] -> all_summaries
        [] -> %{}
      end

    all_alerts = all_alerts || Store.Alerts.fetch([])

    changed_alerts =
      alerts_to_recalculate(
        Map.get(old_summaries_by_locale, @default_locale, %{}),
        all_alerts,
        now
      )

    {time_micros, alerts_with_changed_summaries_by_locale} =
      :timer.tc(fn -> build_all_summaries(changed_alerts, now) end)

    Logger.info(
      "#{__MODULE__} recalculated summaries recalculated=#{length(changed_alerts)} total=#{length(all_alerts)} duration=#{time_micros / 1_000}"
    )

    all_summaries =
      Map.merge(old_summaries_by_locale, alerts_with_changed_summaries_by_locale, fn _locale,
                                                                                     old_alerts_with_summaries,
                                                                                     new_alerts_with_summaries ->
        ids_to_remove =
          MapSet.difference(
            MapSet.new(Map.keys(old_alerts_with_summaries)),
            MapSet.new(Enum.map(all_alerts, & &1.id))
          )

        old_alerts_with_summaries
        |> Map.drop(MapSet.to_list(ids_to_remove))
        |> Map.merge(new_alerts_with_summaries)
      end)

    :ets.insert(ets_table, {:all_summaries, all_summaries})
    all_summaries
  end

  @spec alerts_to_recalculate(%{Alert.id() => AlertWithSummaries.t()}, [Alert.t()], DateTime.t()) ::
          [Alert.t()]
  defp alerts_to_recalculate(old_summary_map, new_alerts, now) do
    new_alerts
    |> Enum.filter(fn alert ->
      old_alert_with_summaries = Map.get(old_summary_map, alert.id)

      if old_alert_with_summaries do
        AlertWithSummaries.should_recalculate_summaries?(old_alert_with_summaries, alert, now)
      else
        true
      end
    end)
  end

  @spec build_all_summaries([Alert.t()], DateTime.t()) :: all_summaries()
  defp build_all_summaries(alerts, now) do
    alerts_by_id = Map.new(alerts, &{&1.id, &1})

    for locale <- Application.get_env(:mobile_app_backend, :locale_codes),
        into: %{} do
      alerts_with_summaries =
        SummaryEntityBuilder.build_all(alerts, now, locale, :card)
        |> Map.new(fn {alert_id, summary_entities} ->
          alert = alerts_by_id[alert_id]
          value = AlertWithSummaries.from_alert(alert, summary_entities, now)
          {alert_id, value}
        end)

      {locale, alerts_with_summaries}
    end
  end
end

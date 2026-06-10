defmodule MobileAppBackend.Alerts.PubSub.Behaviour do
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertWithSummaries

  @doc """
  Subscribe to updates for all alerts
  """
  @callback subscribe(
              legacy_compatibility: boolean(),
              include_summaries: boolean(),
              locale: String.t()
            ) :: %{
              alerts: %{String.t() => Alert.t() | AlertWithSummaries.t()}
            }
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
  alias MobileAppBackend.Alerts.AlertWithSummaries
  alias MobileAppBackend.Alerts.PubSub
  alias MobileAppBackend.Alerts.SummaryEntityBuilder

  @behaviour PubSub.Behaviour

  @default_locale MobileAppBackend.Application.default_locale()
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
  @spec map_data([Alert.t()], boolean(), boolean(), String.t()) :: %{
          String.t() => Alert.t() | AlertWithSummaries.t()
        }
  def map_data(data, legacy_compatibility, include_summaries, locale) do
    summaries_by_alert =
      if include_summaries, do: SummaryEntityBuilder.build_all(data, locale), else: nil

    legacy_map = fn %Alert{} = alert ->
      if MapSet.member?(Alert.v2_causes(), alert.cause),
        do: %Alert{alert | cause: :unknown_cause},
        else: alert
    end

    summary_map = fn alert ->
      AlertWithSummaries.from_alert(alert, Map.get(summaries_by_alert, alert.id, []))
    end

    cond do
      legacy_compatibility -> data |> Enum.map(legacy_map)
      include_summaries -> data |> Enum.map(summary_map)
      true -> data
    end
    |> Enum.map(fn alert -> {alert.id, alert} end)
    |> Map.new()
  end

  @impl true
  def subscribe(opts \\ []) do
    fetch_keys = []

    format_fn = fn data ->
      %{
        alerts:
          data
          |> map_data(
            Keyword.get(opts, :legacy_compatibility, true),
            Keyword.get(opts, :include_summaries, false),
            Keyword.get(opts, :locale, @default_locale)
          )
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
    broadcast_timer(50)

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

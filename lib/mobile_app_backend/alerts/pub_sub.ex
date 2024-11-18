defmodule MobileAppBackend.Alerts.PubSub.Behaviour do
  alias MBTAV3API.JsonApi.Object
  alias MBTAV3API.Alert

  @doc """
  Subscribe to updates for all alerts
  """
  @callback subscribe() :: Object.full_map()
end

defmodule MobileAppBackend.Alerts.PubSub do
  @moduledoc """
  Allows channels to subscribe to alerts data and receive updates as the data changes.

  This broadcasts the latest state of the world (if it has changed) to
  registered consumers in two circumstances:
  1. Regularly scheduled interval - configured by `:alerts_broadcast_interval_ms`
  2. When there is a reset event of the underlying alert stream.
  """
  use GenServer
  alias MBTAV3API.{JsonApi, Store, Stream}
  alias MobileAppBackend.Alerts.PubSub

  @behaviour PubSub.Behaviour

  require Logger

  @fetch_registry_key :fetch_registry_key

  @typedoc """
  tuple {fetch_keys, format_fn} where format_fn transforms the data returned
  into the format expected by subscribers.
  """
  @type registry_value :: {Store.fetch_keys(), function()}

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
  def subscribe() do
    fetch_keys = []

    format_fn = fn data -> JsonApi.Object.to_full_map(data) end

    Registry.register(
      MobileAppBackend.Alerts.Registry,
      @fetch_registry_key,
      {fetch_keys, format_fn}
    )

    fetch_keys
    |> Store.Alerts.fetch()
    |> format_fn.()
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

  @impl true
  # Any time there is a reset_event, broadcast so that subscribers are immediately
  # notified of the changes. This way, when the stream first starts,
  # consumers don't have to wait `:alerts_broadcast_interval_ms` to receive their first message.
  def handle_info(:reset_event, state) do
    send(self(), :broadcast)
    {:noreply, state, :hibernate}
  end

  def handle_info(:timed_broadcast, state) do
    send(self(), :broadcast)
    broadcast_timer()
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def handle_info(:broadcast, %{last_dispatched_table_name: last_dispatched} = state) do
    Registry.dispatch(MobileAppBackend.Alerts.Registry, @fetch_registry_key, fn entries ->
      Enum.group_by(
        entries,
        fn {_, {fetch_keys, format_fn}} -> {fetch_keys, format_fn} end,
        fn {pid, _} -> pid end
      )
      |> Enum.each(fn {registry_value, pids} ->
        broadcast_new_alerts(registry_value, pids, last_dispatched)
      end)
    end)

    {:noreply, state, :hibernate}
  end

  defp broadcast_new_alerts(
         {fetch_keys, format_fn} = registry_value,
         pids,
         last_dispatched_table_name
       ) do
    latest_data =
      fetch_keys
      |> Store.Alerts.fetch()
      |> format_fn.()

    last_dispatched_entry = :ets.lookup(last_dispatched_table_name, registry_value)

    if !already_broadcast(last_dispatched_entry, latest_data) do
      broadcast(pids, latest_data, registry_value, last_dispatched_table_name)
    end
  end

  defp broadcast(
         pids,
         data,
         {fetch_keys, _format_fn} = registry_value,
         last_dispatched_table_name
       ) do
    Logger.info("#{__MODULE__} broadcasting to pids len=#{length(pids)}")

    {time_micros, _result} =
      :timer.tc(__MODULE__, :broadcast_to_pids, [
        pids,
        data
      ])

    Logger.info(
      "#{__MODULE__} broadcast_to_pids fetch_keys=#{inspect(fetch_keys)} duration=#{time_micros / 1000}"
    )

    :ets.insert(last_dispatched_table_name, {registry_value, data})
  end

  defp already_broadcast([], _latest_data) do
    # Nothing has been broadcast yet
    false
  end

  defp already_broadcast([{_registry_key, old_data}], latest_data) do
    old_data == latest_data
  end

  def broadcast_to_pids(pids, data) do
    Enum.each(
      pids,
      &send(
        &1,
        {:stream_data, data}
      )
    )
  end

  defp broadcast_timer do
    interval =
      Application.get_env(:mobile_app_backend, :alerts_broadcast_interval_ms, 500)

    broadcast_timer(interval)
  end

  defp broadcast_timer(interval) do
    Process.send_after(self(), :timed_broadcast, interval)
  end
end

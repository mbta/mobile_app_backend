defmodule MobileAppBackend.Alerts.PubSub.Behaviour do
  alias MBTAV3API.JsonApi.Object

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
  use MobileAppBackend.PubSub,
    broadcast_interval_ms:
      Application.compile_env(:mobile_app_backend, :alerts_broadcast_interval_ms, 500)

  alias MBTAV3API.{JsonApi, Store, Stream}
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

  @impl true
  def subscribe do
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

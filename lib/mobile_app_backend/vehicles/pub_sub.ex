defmodule MobileAppBackend.Vehicles.PubSub.Behaviour do
  alias MBTAV3API.{Route, Vehicle}

  @doc """
  Subscribe to vehicle updates for the given routes & direction
  """
  @callback subscribe_for_routes([Route.id()], 0 | 1) :: [Vehicle.t()]

  @doc """
  Subscribe to updates for the given vehicle
  """
  @callback subscribe(Vehicle.id()) :: Vehicle.t() | nil
end

defmodule MobileAppBackend.Vehicles.PubSub do
  @moduledoc """
  Allows channels to subscribe to the subset of vehicles they are interested
  in and receive updates as the vehicles data changes.

  For each subset of vehicles that channels are actively subscribed to, this broadcasts
  the latest state of the world (if it has changed) to the registered consumer in two circumstances
  1. Regularly scheduled interval - configured by `:vehicles_broadcast_interval_ms`
  2. When there is a reset event of the underlying vehicle stream.
  """
  use MobileAppBackend.PubSub,
    broadcast_interval_ms:
      Application.compile_env(:mobile_app_backend, :vehicles_broadcast_interval_ms, 500)

  alias MBTAV3API.{Store, Stream}
  alias MobileAppBackend.Vehicles.PubSub

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
  def subscribe_for_routes(route_ids, direction_id) do
    route_fetch_key_pairs = Enum.map(route_ids, &[route_id: &1, direction_id: direction_id])

    Registry.register(
      MobileAppBackend.Vehicles.Registry,
      @fetch_registry_key,
      {route_fetch_key_pairs, fn data -> data end}
    )

    Store.Vehicles.fetch(route_fetch_key_pairs)
  end

  @impl true
  def subscribe(vehicle_id) do
    fetch_keys = [id: vehicle_id]

    format_fn = fn data ->
      case data do
        [vehicle | _shouldnt_be_rest] -> vehicle
        _ -> nil
      end
    end

    Registry.register(
      MobileAppBackend.Vehicles.Registry,
      @fetch_registry_key,
      {fetch_keys, format_fn}
    )

    fetch_keys
    |> Store.Vehicles.fetch()
    |> format_fn.()
  end

  @impl GenServer
  def init(opts \\ []) do
    Stream.StaticInstance.subscribe("vehicles:to_store")

    broadcast_timer(50)

    create_table_fn =
      Keyword.get(opts, :create_table_fn, fn ->
        :ets.new(:last_dispatched_vehicles, [:set, :named_table])
        {:ok, %{last_dispatched_table_name: :last_dispatched_vehicles}}
      end)

    create_table_fn.()
  end

  @impl GenServer
  def handle_info(:broadcast, %{last_dispatched_table_name: last_dispatched} = state) do
    Registry.dispatch(MobileAppBackend.Vehicles.Registry, @fetch_registry_key, fn entries ->
      entries
      |> MobileAppBackend.PubSub.group_pids_by_target_data()
      |> Enum.each(fn {{fetch_keys, format_fn} = registry_value, pids} ->
        fetch_keys
        |> Store.Vehicles.fetch()
        |> format_fn.()
        |> MobileAppBackend.PubSub.broadcast_latest_data(
          :new_vehicles,
          registry_value,
          pids,
          last_dispatched
        )
      end)
    end)

    {:noreply, state, :hibernate}
  end
end

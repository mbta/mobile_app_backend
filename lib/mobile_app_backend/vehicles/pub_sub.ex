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
  use GenServer
  alias MBTAV3API.{Store, Stream}
  alias MobileAppBackend.Vehicles.PubSub

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

  @impl true
  # Any time there is a reset_event, broadcast so that subscribers are immediately
  # notified of the changes. This way, when the vehicle stream first starts,
  # consumers don't have to wait `:vehicles_broadcast_interval_ms` to receive their first message.
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
    Registry.dispatch(MobileAppBackend.Vehicles.Registry, @fetch_registry_key, fn entries ->
      Enum.group_by(
        entries,
        fn {_, {fetch_keys, format_fn}} -> {fetch_keys, format_fn} end,
        fn {pid, _} -> pid end
      )
      |> Enum.each(fn {registry_value, pids} ->
        broadcast_new_vehicles(registry_value, pids, last_dispatched)
      end)
    end)

    {:noreply, state, :hibernate}
  end

  defp broadcast_new_vehicles(
         {fetch_keys, format_fn} = registry_value,
         pids,
         last_dispatched_table_name
       ) do
    new_vehicles =
      fetch_keys
      |> Store.Vehicles.fetch()
      |> format_fn.()

    last_dispatched_entry = :ets.lookup(last_dispatched_table_name, registry_value)

    if !vehicles_already_broadcast(last_dispatched_entry, new_vehicles) do
      broadcast_vehicles(pids, new_vehicles, registry_value, last_dispatched_table_name)
    end
  end

  defp broadcast_vehicles(
         pids,
         vehicles,
         {fetch_keys, _format_fn} = registry_value,
         last_dispatched_table_name
       ) do
    Logger.info("#{__MODULE__} broadcasting to pids len=#{length(pids)}")

    {time_micros, _result} =
      :timer.tc(__MODULE__, :broadcast_to_pids, [
        pids,
        vehicles
      ])

    Logger.info(
      "#{__MODULE__} broadcast_to_pids fetch_keys=#{inspect(fetch_keys)} duration=#{time_micros / 1000}"
    )

    :ets.insert(last_dispatched_table_name, {registry_value, vehicles})
  end

  defp vehicles_already_broadcast([], _new_vehicles) do
    # Nothing has been broadcast yet
    false
  end

  defp vehicles_already_broadcast([{_registry_key, last_vehicles}], new_vehicles) do
    last_vehicles == new_vehicles
  end

  def broadcast_to_pids(pids, vehicles) do
    Enum.each(
      pids,
      &send(
        &1,
        {:new_vehicles, vehicles}
      )
    )
  end

  defp broadcast_timer do
    interval =
      Application.get_env(:mobile_app_backend, :vehicles_broadcast_interval_ms, 500)

    broadcast_timer(interval)
  end

  defp broadcast_timer(interval) do
    Process.send_after(self(), :timed_broadcast, interval)
  end
end

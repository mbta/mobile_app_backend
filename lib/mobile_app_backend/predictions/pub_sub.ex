defmodule MobileAppBackend.Predictions.PubSub.Behaviour do
  alias MBTAV3API.JsonApi
  alias MBTAV3API.{Prediction, Stop, Trip, Vehicle}

  @type predictions_for_stop :: %{Stop.id() => JsonApi.Object.full_map()}

  @type subscribe_response :: %{
          predictions_by_stop: %{Stop.id() => %{Prediction.id() => Prediction.t()}},
          trips: %{Trip.id() => Trip.t()},
          vehicles: %{Vehicle.id() => Vehicle.t()}
        }

  @doc """
  Subscribe to prediction updates for the given stop. For a parent station, this subscribes to updates for all child stops.
  """
  @callback subscribe_for_stop(Stop.id()) :: subscribe_response()
  @doc """
  Subscribe to prediction updates for multiple stops. For  parent stations, this subscribes to updates for all their child stops.
  """
  @callback subscribe_for_stops([Stop.id()]) :: subscribe_response()
end

defmodule MobileAppBackend.Predictions.PubSub do
  @moduledoc """
  Allows channels to subscribe to the subset of predictions they are interested
  in and receive updates as the prediction data changes.

  For each subset of predictions that channels are actively subscribed to, this broadcasts
  the latest state of the world (if it has changed) to the registered consumer in two circumstances
  1. Regularly scheduled interval - configured by `:predictions_broadcast_interval_ms`
  2. When there is a reset event of the underlying prediction streams.

  Based on https://github.com/mbta/dotcom/blob/main/lib/predictions/pub_sub.ex
  """
  use GenServer
  alias MBTAV3API.Stream.StaticInstance
  alias MBTAV3API.{JsonApi, Prediction, Stop, Store, Stream}
  alias MobileAppBackend.Predictions.PubSub

  @behaviour PubSub.Behaviour

  require Logger

  @fetch_registry_key :fetch_registry_key

  @typedoc """
  tuple {fetch_keys, format_fn} where format_fn transforms the data returned
  from fetching predictions from the store into the format expected by subscribers.
  """
  @type registry_value :: {Store.fetch_keys(), function()}
  @type broadcast_message :: {:new_predictions, %{Stop.id() => JsonApi.Object.full_map()}}

  @type state :: %{last_dispatched_table_name: atom()}

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(
      __MODULE__,
      opts,
      name: name
    )
  end

  @impl true
  def subscribe_for_stops(stop_ids) do
    {:ok, %{data: _stop, included: %{stops: child_stops}}} =
      MBTAV3API.Repository.stops(filter: [id: stop_ids], include: :child_stops)

    child_stops =
      child_stops
      |> Map.values()
      |> Enum.filter(&(&1.location_type == :stop))

    child_stop_ids = Enum.map(child_stops, & &1.id)

    child_ids_by_parent_id =
      child_stops
      |> Enum.map(&{&1.parent_station_id, &1.id})
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    {time_micros, _result} =
      :timer.tc(MobileAppBackend.Predictions.StreamSubscriber, :subscribe_for_stops, [
        stop_ids ++ child_stop_ids
      ])

    Logger.info(
      "#{__MODULE__} subscribe_for_stops stop_id=#{inspect(stop_ids)} duration=#{time_micros / 1000}"
    )

    all_predictions_data =
      stop_ids
      |> register_all_stops(child_ids_by_parent_id)
      |> Store.Predictions.fetch_with_associations()

    predictions_by_stop =
      group_predictions_for_stop(
        all_predictions_data.predictions,
        stop_ids,
        child_ids_by_parent_id
      )

    %{
      predictions_by_stop: predictions_by_stop,
      trips: all_predictions_data.trips,
      vehicles: all_predictions_data.vehicles
    }
  end

  @impl true
  def subscribe_for_stop(stop_id) do
    subscribe_for_stops([stop_id])
  end

  @spec group_predictions_for_stop(%{Prediction.id() => Prediction.t()}, [Stop.id()], %{
          Stop.id() => [Stop.id()]
        }) :: %{Stop.id() => %{Prediction.id() => Prediction.t()}}
  defp group_predictions_for_stop(predictions, stop_ids, child_ids_by_parent_id) do
    prediction_list_by_stop =
      predictions
      |> Map.values()
      |> Enum.group_by(& &1.stop_id)

    Map.new(stop_ids, fn stop_id ->
      case Map.get(child_ids_by_parent_id, stop_id) do
        nil ->
          {stop_id,
           prediction_list_by_stop
           |> Map.get(stop_id, [])
           |> Map.new(&{&1.id, &1})}

        child_ids ->
          {stop_id,
           prediction_list_by_stop
           |> Map.take(child_ids)
           |> Map.values()
           |> Enum.concat()
           |> Map.new(&{&1.id, &1})}
      end
    end)
  end

  @spec register_all_stops([Stop.id()], %{Stop.id() => [Stop.id()]}) :: Store.fetch_keys()
  defp register_all_stops(stop_ids, child_ids_by_parent_id) do
    stop_ids
    |> Enum.flat_map(fn stop_id ->
      case Map.get(child_ids_by_parent_id, stop_id) do
        nil ->
          [register_single_stop(stop_id)]

        child_ids ->
          register_parent_stop(stop_id, child_ids)
      end
    end)
  end

  @spec register_single_stop(Stop.id()) :: Store.fetch_keys()
  defp register_single_stop(stop_id) do
    fetch_keys = [stop_id: stop_id]

    {:ok, _owner} =
      Registry.register(
        MobileAppBackend.Predictions.Registry,
        @fetch_registry_key,
        {fetch_keys, fn data -> %{stop_id => data} end}
      )

    fetch_keys
  end

  @spec register_parent_stop(Stop.id(), [Stop.id()]) :: Store.fetch_keys()
  defp register_parent_stop(parent_stop_id, child_stop_ids) do
    # Fetch predictions by the relevant child stop ids. Return data & broadcast
    # future updates with format `%{parent_stop_id => predictions}`, rather than
    # separately broadcasting predictions for each child stop
    fetch_keys = Enum.map(child_stop_ids, &[stop_id: &1])

    {:ok, _owner} =
      Registry.register(
        MobileAppBackend.Predictions.Registry,
        @fetch_registry_key,
        {fetch_keys, fn data -> %{parent_stop_id => data} end}
      )

    fetch_keys
  end

  @impl GenServer
  def init(opts \\ []) do
    # Predictions are streamed from the V3 API by route, but events are aggregated
    # under this single topic
    Stream.PubSub.subscribe("predictions:all:events")

    # There is only one vehicle stream - subscribe & start it if it hasn't already been started
    StaticInstance.subscribe("vehicles:to_store", include_current_data: false)

    broadcast_timer(50)

    create_table_fn =
      Keyword.get(opts, :create_table_fn, fn ->
        :ets.new(:last_dispatched, [:set, :named_table])
        {:ok, %{last_dispatched_table_name: :last_dispatched}}
      end)

    create_table_fn.()
  end

  @impl true
  # Any time there is a reset_event, broadcast so that subscribers are immediately
  # notified of the changes. This way, when a prediction stream first starts,
  # consumers don't have to wait `:predictions_broadcast_interval_ms` to receive their first message.
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
    Registry.dispatch(MobileAppBackend.Predictions.Registry, @fetch_registry_key, fn entries ->
      Enum.group_by(
        entries,
        fn {_, {fetch_keys, format_fn}} -> {fetch_keys, format_fn} end,
        fn {pid, {_, _}} -> pid end
      )
      |> Enum.each(fn {registry_value, pids} ->
        broadcast_new_predictions(registry_value, pids, last_dispatched)
      end)
    end)

    {:noreply, state, :hibernate}
  end

  defp broadcast_new_predictions(
         {fetch_keys, format_fn} = registry_value,
         pids,
         last_dispatched_table_name
       ) do
    new_predictions =
      fetch_keys
      |> Store.Predictions.fetch_with_associations()
      |> format_fn.()

    last_dispatched_entry = :ets.lookup(last_dispatched_table_name, registry_value)

    if !predictions_already_broadcast(last_dispatched_entry, new_predictions) do
      broadcast_predictions(pids, new_predictions, registry_value, last_dispatched_table_name)
    end
  end

  defp broadcast_predictions(pids, predictions, registry_value, last_dispatched_table_name) do
    Logger.info("#{__MODULE__} broadcasting to pids len=#{length(pids)}")

    {time_micros, _result} =
      :timer.tc(__MODULE__, :broadcast_to_pids, [
        pids,
        predictions
      ])

    Logger.info(
      "#{__MODULE__} broadcast_to_pids fetch_keys=#{inspect(elem(registry_value, 0))}duration=#{time_micros / 1000}"
    )

    :ets.insert(last_dispatched_table_name, {registry_value, predictions})
  end

  defp predictions_already_broadcast([], _new_preidctions) do
    # Nothing has been broadcast yet
    false
  end

  defp predictions_already_broadcast([{_registry_key, last_predictions}], new_predictions) do
    last_predictions == new_predictions
  end

  def broadcast_to_pids(pids, predictions) do
    Enum.each(
      pids,
      &send(
        &1,
        {:new_predictions, predictions}
      )
    )
  end

  defp broadcast_timer do
    interval =
      Application.get_env(:mobile_app_backend, :predictions_broadcast_interval_ms, 10_000)

    broadcast_timer(interval)
  end

  defp broadcast_timer(interval) do
    Process.send_after(self(), :timed_broadcast, interval)
  end
end

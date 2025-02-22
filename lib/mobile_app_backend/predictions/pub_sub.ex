defmodule MobileAppBackend.Predictions.PubSub.Behaviour do
  alias MBTAV3API.JsonApi
  alias MBTAV3API.{Prediction, Stop, Trip, Vehicle}

  @type predictions_for_stop :: %{Stop.id() => JsonApi.Object.full_map()}

  @type subscribe_stop_response :: %{
          predictions_by_stop: %{Stop.id() => %{Prediction.id() => Prediction.t()}},
          trips: %{Trip.id() => Trip.t()},
          vehicles: %{Vehicle.id() => Vehicle.t()}
        }

  @type subscribe_trip_response ::
          %{
            trip_id: Trip.id(),
            predictions: %{Prediction.id() => Prediction.t()},
            trips: %{Trip.id() => Trip.t()},
            vehicles: %{Vehicle.id() => Vehicle.t()}
          }
          | :error

  @doc """
  Subscribe to prediction updates for the given stop. For a parent station, this subscribes to updates for all child stops.
  """
  @callback subscribe_for_stop(Stop.id()) :: subscribe_stop_response()
  @doc """
  Subscribe to prediction updates for multiple stops. For  parent stations, this subscribes to updates for all their child stops.
  """
  @callback subscribe_for_stops([Stop.id()]) :: subscribe_stop_response()
  @doc """
  Subscribe to prediction updates for the given trip.
  """
  @callback subscribe_for_trip(Trip.id()) :: subscribe_trip_response()
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
  use MobileAppBackend.PubSub,
    broadcast_interval_ms:
      Application.compile_env(:mobile_app_backend, :predictions_broadcast_interval_ms, 10_000)

  alias MBTAV3API.{Prediction, Stop, Store, Stream, Trip, Vehicle}
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Predictions.PubSub

  require Logger

  @behaviour PubSub.Behaviour

  @fetch_registry_key :fetch_registry_key

  @type broadcast_message ::
          {:new_predictions,
           %{
             stop_id: Stop.id(),
             predictions: %{Prediction.id() => Prediction.t()},
             trips: %{Trip.id() => Trip.t()},
             vehicles: %{Vehicle.id() => Vehicle.t()}
           }}

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
  def subscribe_for_stops(stop_ids) do
    %{stops: all_stops_by_id} = GlobalDataCache.get_data()
    stop_id_to_children = Stop.stop_id_to_children(all_stops_by_id, stop_ids)

    child_stop_ids =
      stop_id_to_children
      |> Map.values()
      |> List.flatten()

    {time_micros, :ok} =
      :timer.tc(MobileAppBackend.Predictions.StreamSubscriber, :subscribe_for_stops, [
        stop_ids ++ child_stop_ids
      ])

    Logger.info(
      "#{__MODULE__} subscribe_for_stops stop_id=#{inspect(stop_ids)} duration=#{time_micros / 1000} "
    )

    all_predictions_data =
      stop_ids
      |> register_all_stops(stop_id_to_children)
      |> Store.Predictions.fetch_with_associations()

    predictions_by_stop =
      group_predictions_for_stop(
        all_predictions_data.predictions,
        stop_ids,
        stop_id_to_children
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

  @impl true
  def subscribe_for_trip(trip_id) do
    case :timer.tc(MobileAppBackend.Predictions.StreamSubscriber, :subscribe_for_trip, [trip_id]) do
      {time_micros, :ok} ->
        Logger.info(
          "#{__MODULE__} subscribe_for_trip trip_id=#{trip_id} duration=#{time_micros / 1000} "
        )

        predictions_data =
          register_trip(trip_id)
          |> Store.Predictions.fetch_with_associations()

        %{
          trip_id: trip_id,
          predictions: predictions_data.predictions,
          trips: predictions_data.trips,
          vehicles: predictions_data.vehicles
        }

      {time_micros, :error} ->
        Logger.warning(
          "#{__MODULE__} failed to subscribe_for_trip trip_id=#{trip_id} duration=#{time_micros / 1000} "
        )

        :error
    end
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
      case Map.get(child_ids_by_parent_id, stop_id, []) do
        [] ->
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
      case Map.get(child_ids_by_parent_id, stop_id, []) do
        [] ->
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
        {fetch_keys, fn data -> Map.put(data, :stop_id, stop_id) end}
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
        {fetch_keys, fn data -> Map.put(data, :stop_id, parent_stop_id) end}
      )

    fetch_keys
  end

  @spec register_trip(Trip.id()) :: Store.fetch_keys()
  defp register_trip(trip_id) do
    fetch_keys = [trip_id: trip_id]

    {:ok, _owner} =
      Registry.register(
        MobileAppBackend.Predictions.Registry,
        @fetch_registry_key,
        {fetch_keys, fn data -> Map.put(data, :trip_id, trip_id) end}
      )

    fetch_keys
  end

  @impl GenServer
  def init(opts \\ []) do
    # Predictions are streamed from the V3 API by route,
    # but reset event messages are aggregated under this single topic
    Stream.PubSub.subscribe("predictions:all:events")
    Stream.PubSub.subscribe("vehicles:to_store")

    broadcast_timer(50)

    create_table_fn =
      Keyword.get(opts, :create_table_fn, fn ->
        :ets.new(:last_dispatched, [:set, :named_table])
        {:ok, %{last_dispatched_table_name: :last_dispatched}}
      end)

    create_table_fn.()
  end

  @impl GenServer
  def handle_info(:broadcast, %{last_dispatched_table_name: last_dispatched} = state) do
    Registry.dispatch(MobileAppBackend.Predictions.Registry, @fetch_registry_key, fn entries ->
      entries
      |> MobileAppBackend.PubSub.group_pids_by_target_data()
      |> Enum.each(fn {{fetch_keys, format_fn} = registry_value, pids} ->
        fetch_keys
        |> Store.Predictions.fetch_with_associations()
        |> format_fn.()
        |> MobileAppBackend.PubSub.broadcast_latest_data(
          :new_predictions,
          registry_value,
          pids,
          last_dispatched
        )
      end)
    end)

    {:noreply, state, :hibernate}
  end
end

defmodule MobileAppBackend.StopPredictions.PubSub do
  @moduledoc """
  A Genserver that manages predictions for a single stop.
  Subscribes to predictions for all routes serving that stop and publishes a message
  when the stop's predictions have changed.
  """
  use GenServer
  alias Credo.CLI.Command.Categories.Output.Json
  alias MBTAV3API.{JsonApi, JsonApi.Object, Prediction, Route, Stop, Stream, Trip, Vehicle}
  alias MobileAppBackend.StopPredictions
  require Logger

  @broadcast_interval_ms Application.compile_env!(:mobile_app_backend, __MODULE__)[
                           :broadcast_interval_ms
                         ]

  @type t :: %{
          all_stop_ids: [Stop.id()],
          stop_id: Stop.id(),
          route_ids: [Route.id()],
          last_broadcast_msg: MBTAV3API.JsonApi.Object.full_map() | nil
        }

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    stop_id = Keyword.fetch!(args, :stop_id)

    GenServer.start_link(__MODULE__, args, name: StopPredictions.Registry.via_name(stop_id))
  end

  @impl GenServer
  def init(opts) do
    stop_id = Keyword.fetch!(opts, :stop_id)

    {:ok, %{included: %{stops: extra_stops}}} =
      MBTAV3API.Repository.stops(filter: [id: stop_id], include: :child_stops)

    child_stop_ids =
      Map.values(extra_stops)
      |> Enum.filter(&(&1.location_type == :stop))
      |> Enum.map(& &1.id)

    stop_ids = Enum.uniq([stop_id] ++ child_stop_ids)

    {:ok, %{data: routes}} = MBTAV3API.Repository.routes(filter: [stop: stop_ids])

    :ok =
      Enum.each(routes, fn %MBTAV3API.Route{id: route_id} ->
        {:ok, _data} =
          MBTAV3API.Stream.StaticInstance.subscribe("predictions:from_store:route:#{route_id}")
      end)

    broadcast_timer()

    {:ok,
     %{
       stop_id: stop_id,
       all_stop_ids: stop_ids,
       route_ids: Enum.map(routes, & &1.id),
       last_broadcast_msg: nil
     }}
  end

  def subscribe(stop_id) do
    with :ok <- Phoenix.PubSub.subscribe(__MODULE__, topic(stop_id)) do
      if is_nil(StopPredictions.Registry.find_pid(stop_id)) do
        StopPredictions.Supervisor.start_instance(stop_id: stop_id, name: stop_id)
      end

      current_data =
        GenServer.call(StopPredictions.Registry.via_name(stop_id), :get_data)

      {:ok, current_data}
    end
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, fetch_stop_predictions(state.all_stop_ids), state}
  end

  @spec fetch_stop_predictions([Stop.id()]) :: JsonApi.Object.full_map()
  @doc """
  Retreive the latest predictions for the given stops from the prediction store.
  """
  def fetch_stop_predictions(stop_ids) do
    stop_ids
    #TODO: This is currently doing syncronous reads - adjust that
    |> Enum.flat_map(
      &MobileAppBackend.Predictions.Store.predictions_for_keys(MobileAppBackend.Predictions.Store, stop_id: &1))
    |> JsonApi.Object.to_full_map()
  end

  @impl true
  # When receiving the first predictions from a route, broadcast to ensure that consumers
  # Don't have to wait until the timed broadcast to receive initial data
  #TODO: only handle_info for inital message
  #def handle_info({:stream_data, "predictions:from_store:route:" <> _route_id, _}, state) do
 #   if state.last_broadcast_msg == nil do
 #     state_with_broadcast = broadcast(state)
#
 #     {:noreply, state_with_broadcast}
 #   else
 #     {:noreply, state}
#    end
 # end

  def handle_info(:timed_broadcast, state) do
    send(self(), :broadcast)
    broadcast_timer()
    {:noreply, state, :hibernate}
  end

  def handle_info(:broadcast, state) do
    state_after_broadcast = broadcast(state)

    {:noreply, state_after_broadcast, :hibernate}
  end

  @spec broadcast(%{
          :all_stop_ids => [binary()],
          :last_broadcast_msg => any(),
          optional(any()) => any()
        }) :: %{
          :all_stop_ids => [binary()],
          :last_broadcast_msg => %{
            alerts: %{optional(binary()) => map()},
            lines: %{optional(binary()) => map()},
            predictions: %{optional(binary()) => map()},
            route_patterns: %{optional(binary()) => map()},
            routes: %{optional(binary()) => map()},
            schedules: %{optional(binary()) => map()},
            shapes: %{optional(binary()) => map()},
            stops: %{optional(binary()) => map()},
            trips: %{optional(binary()) => map()},
            vehicles: %{optional(binary()) => map()}
          },
          optional(any()) => any()
        }
  @doc """
  Broadcast the state of the world of predictions for the target stop in the format
  %{Stop.id() => JsonApi.Object.full_map()}
  """
  def broadcast(state) do
    last_broadcast_msg = state.last_broadcast_msg
    data_to_broadcast = fetch_stop_predictions(state.all_stop_ids)

    Logger.debug("BROADCAST MAYBE #{DateTime.utc_now()}")

    if last_broadcast_msg != data_to_broadcast do
      Logger.debug("BROADCAST PREICTIONS #{inspect(data_to_broadcast)}")

      Phoenix.PubSub.broadcast!(__MODULE__, topic(state.stop_id), {
        :new_predictions,
        %{state.stop_id => data_to_broadcast}
      })
    end

    %{state | last_broadcast_msg: data_to_broadcast}
  end

  defp broadcast_timer(interval \\ @broadcast_interval_ms) do
    Process.send_after(self(), :timed_broadcast, interval)
  end

  @doc """
  The topic to broadcast messages about predictions updates to
  """
  @spec topic(Stop.id()) :: String.t()
  def topic(stop_id) do
    "predictions:stop:instance:#{stop_id}"
  end

  @spec merge_data(%{String.t() => JsonApi.Object.full_map()}) :: JsonApi.Object.full_map()
  defp merge_data(data) do
    data
    |> Map.values()
    |> Enum.reduce(JsonApi.Object.to_full_map([]), &JsonApi.Object.merge_full_map/2)
  end
end

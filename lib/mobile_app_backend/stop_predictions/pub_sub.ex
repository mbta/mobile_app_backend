defmodule MobileAppBackend.StopPredictions.PubSub do
  @moduledoc """
  A Genserver that manages predictions for a single stop.
  Subscribes to predictions for all routes serving that stop and publishes a message
  when the stop's predictions have changed.
  """
  use GenServer
  alias MBTAV3API.{JsonApi, Prediction, Route, Stop, Trip, Vehicle}
  alias MobileAppBackend.StopPredictions
  require Logger

  @broadcast_interval_ms Application.compile_env!(:mobile_app_backend, __MODULE__)[
                           :broadcast_interval_ms
                         ]

  @type t :: %{
          data: %{
            by_route: %{
              Route.id() => %{
                predictions: %{Prediction.id() => Prediction.t()},
                trips: %{Trip.id() => Trip.t()},
                vehicles: %{Vehicle.id() => Vehicle.t()}
              }
            }
          },
          all_stop_ids: [Stop.id()],
          stop_id: Stop.id(),
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

    data =
      Map.new(routes, fn %MBTAV3API.Route{id: route_id} ->
        {:ok, data} =
          MBTAV3API.Stream.StaticInstance.subscribe("predictions:route:#{route_id}")

        {route_id, filter_data(data, stop_ids)}
      end)

    broadcast_timer()

    {:ok,
     %{stop_id: stop_id, all_stop_ids: stop_ids, last_broadcast_msg: nil, data: %{by_route: data}}}
  end

  def subscribe(stop_id) do
    with :ok <- Phoenix.PubSub.subscribe(__MODULE__, topic(stop_id)) do
      if is_nil(StopPredictions.Registry.find_pid(stop_id)) do
        StopPredictions.Supervisor.start_instance(stop_id: stop_id, name: stop_id)
      end

      current_data = GenServer.call(StopPredictions.Registry.via_name(stop_id), :get_data)

      {:ok, merge_data(current_data.by_route)}
    end
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state.data, state}
  end

  @impl true
  def handle_info({:stream_data, "predictions:route:" <> route_id, data}, state) do
    old_data = state.data

    new_data =
      put_in(old_data, [:by_route, route_id], filter_data(data, state.all_stop_ids))

    new_state = %{state | data: new_data}

    if state.last_broadcast_msg == nil do
      state_with_broadcast = broadcast(new_state)

      {:noreply, state_with_broadcast}
    else
      {:noreply, new_state}
    end
  end

  def handle_info(:timed_broadcast, state) do
    send(self(), :broadcast)
    broadcast_timer()
    {:noreply, state, :hibernate}
  end

  def handle_info(:broadcast, state) do
    state_after_broadcast = broadcast(state)

    {:noreply, state_after_broadcast, :hibernate}
  end

  def broadcast(state) do
    last_broadcast_msg = state.last_broadcast_msg
    data_to_broadcast = merge_data(state.data.by_route)

    if last_broadcast_msg != data_to_broadcast do
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

  def topic(stop_id) do
    "predictions:stop:instance:#{stop_id}"
  end

  def filter_data(route_data, stop_ids) do
    %{predictions: predictions, trip_ids: trip_ids, vehicle_ids: vehicle_ids} =
      for {_, %Prediction{} = prediction} <- route_data.predictions,
          reduce: %{predictions: %{}, trip_ids: [], vehicle_ids: []} do
        %{predictions: predictions, trip_ids: trip_ids, vehicle_ids: vehicle_ids} ->
          if prediction.stop_id in stop_ids do
            %{
              predictions: Map.put(predictions, prediction.id, prediction),
              trip_ids: [prediction.trip_id | trip_ids],
              vehicle_ids: [prediction.vehicle_id | vehicle_ids]
            }
          else
            %{predictions: predictions, trip_ids: trip_ids, vehicle_ids: vehicle_ids}
          end
      end

    %{
      MBTAV3API.JsonApi.Object.to_full_map([])
      | predictions: predictions,
        trips: Map.take(route_data.trips, trip_ids),
        vehicles: Map.take(route_data.vehicles, vehicle_ids)
    }
  end

  @spec merge_data(%{String.t() => JsonApi.Object.full_map()}) :: JsonApi.Object.full_map()
  defp merge_data(data) do
    data
    |> Map.values()
    |> Enum.reduce(JsonApi.Object.to_full_map([]), &JsonApi.Object.merge_full_map/2)
  end
end

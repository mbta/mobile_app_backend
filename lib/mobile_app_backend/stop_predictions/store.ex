defmodule MobileAppBackend.Predictions.Store do
  @moduledoc """
  Server for saving and editing predictions in an ETS table. Predictions are
  added, removed, and updated by other processes via `update/2`. Predictions can
  be retrieved using `fetch/1` for any combination of values specified of
  `fetch_keys`.
  """

  use GenServer

  require Logger

  alias MBTAV3API.Prediction
  # alias Predictions.Store.Behaviour

  @behaviour Behaviour

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Deletes predictions associated with the input fetch keys, e.g. clear([route: 'Red', direction: 1])"
  def clear(keys) do
    GenServer.cast(__MODULE__, {:remove, Enum.map(fetch(keys), & &1.id)})
  end

  def fetch(keys) do
    GenServer.call(__MODULE__, {:fetch, keys})
  end

  def update({event, data}, scope) do
    GenServer.cast(__MODULE__, {event, data})
  end

  def update(events, scope) when is_list(events) do
    Enum.each(events, &update(&1, scope))
  end

  # Server
  def init(_) do
    table = :ets.new(__MODULE__, [:public])
    #  periodic_delete()
    {:ok, table}
  end

  @impl GenServer
  def handle_cast({_, []}, table), do: {:noreply, table}

  def handle_cast({event, data}, table) when event in [:add, :update] do
    Logger.info("Add / update event #{inspect(data)}")
    :ets.insert(table, Enum.map(data.predictions, &to_record/1))

    {:noreply, table}
  end

  def handle_cast({:remove, prediction_ids}, table) do
    Logger.info("Remove predictions event: #{inspect(prediction_ids)}")

    #  for id <- prediction_ids do
    #    :ets.delete(table, id)
    #  end

    {:noreply, table}
  end

  def handle_cast({:reset, data}, scope, table) do
    Logger.info("Reset event #{inspect(scope)}")

    #  scope
    # |> Map.to_list()
    # |> clear()

    #  update({:add, data}, scope)

    {:noreply, table}
  end

  def handle_cast(_, table), do: {:noreply, table}

  @impl GenServer
  def handle_call({:fetch, keys}, _from, table) do
    predictions = predictions_for_keys(table, keys)
    {:reply, predictions, table}
  end

  @impl GenServer
  def handle_info(:periodic_delete, table) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    # delete predictions with a time earlier than a minute ago
    :ets.select_delete(table, [
      {{
         :_,
         :"$1",
         :_,
         :_,
         :_,
         :_,
         :_,
         :_,
         :_
       }, [{:<, :"$1", now - 60}], [true]}
    ])

    periodic_delete()
    {:noreply, table}
  end

  @spec predictions_for_keys(:ets.table(), Behaviour.fetch_keys()) :: [Prediction.t()]
  defp predictions_for_keys(table, opts) do
    match_pattern = {
      Keyword.get(opts, :prediction_id, :_) || :_,
      :_,
      :_,
      Keyword.get(opts, :route_id, :_) || :_,
      Keyword.get(opts, :stop_id, :_) || :_,
      Keyword.get(opts, :direction_id, :_) || :_,
      Keyword.get(opts, :trip_id, :_) || :_,
      Keyword.get(opts, :vehicle_id, :_) || :_,
      :"$1"
    }

    :ets.select(table, [{match_pattern, [], [:"$1"]}])
  end

  defp to_record(
         %Prediction{
           id: id,
           # TODO: if we periodic delete based on arrival / departure time,
           # Cancelled trip predictions would stay in the table indefinitely
           # Do we need periodic delete if we are already doing resets?
           arrival_time: arrival_time,
           departure_time: departure_time,
           direction_id: direction_id,
           route_id: route_id,
           stop_id: stop_id,
           trip_id: trip_id,
           vehicle_id: vehicle_id
         } = prediction
       ) do
    {
      id,
      arrival_time,
      departure_time,
      route_id,
      stop_id,
      direction_id,
      trip_id,
      vehicle_id,
      prediction
    }
  end

  defp periodic_delete do
    Process.send_after(self(), :periodic_delete, 300_000)
  end
end

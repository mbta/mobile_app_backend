defmodule MobileAppBackend.Predictions.Store do
  @moduledoc """
  Server for saving and editing predictions in an ETS table. Predictions are
  added, removed, and process_eventd by other processes via `process_event/2`. Predictions can
  be retrieved using `fetch/1` for any combination of values specified of
  `fetch_keys`.
  """

  use GenServer

  require Logger

  alias MBTAV3API.JsonApi.Reference
  alias MBTAV3API.{Prediction, Trip, Vehicle}

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Deletes predictions associated with the input fetch keys, e.g. clear([route: 'Red', direction: 1])"
  def clear(keys) do
    GenServer.cast(__MODULE__, {:remove, Enum.map(fetch(keys), &%Reference{type: "prediction", id: &1})})
  end

  def fetch(keys) do
    GenServer.call(__MODULE__, {:fetch, keys})
  end

  def process_event({event, data}, scope) do
    GenServer.cast(__MODULE__, {event, data, scope})
  end

  def process_event(events, scope) when is_list(events) do
    Enum.each(events, &process_event(&1, scope))
  end

  # Server
  @impl true
  def init(_) do
    table = :ets.new(__MODULE__, [:public, :named_table])
    #  periodic_delete()
    {:ok, table}
  end

  @impl true
  def handle_cast({event, data, _scope}, table) when event in ["add", "update"] do
    prediction_records =
      data
      # TODO: what about other types
      |> Enum.filter(&match?(%Prediction{}, &1))
      |> Enum.map(&to_record/1)

    :ets.insert(table, prediction_records)

    {:noreply, table}
  end

  def handle_cast({"remove", references, _scope}, table) do

    do_remove(references, table)

    {:noreply, table}
  end


  def handle_cast({"reset", data, scope}, table) do
    do_clear(scope, table)

    process_event({"add", data}, scope)

    {:noreply, table}
  end

  def handle_cast(other, table) do
    Logger.warning("#{__MODULE__} cast not matched #{inspect(other)}")
    {:noreply, table}
  end

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

  def do_remove(references, table) do
    for reference <- references do
      case reference do
        %{type: "prediction", id: id} -> :ets.delete(table, id)
        _ -> :ok
      end
    end

  end


  def do_clear(keys, table) do
    table
    |> predictions_for_keys(keys)
    |> Enum.map(&%Reference{type: "prediction", id: &1})
    |> do_remove(table)

  end

  @spec predictions_for_keys(:ets.table(), Behaviour.fetch_keys()) :: [Prediction.t()]
  #TODO: temporarily public to see if this helps with scaling
  def predictions_for_keys(table, opts) do
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

    #https://github.com/mbta/skate/blob/main/lib/util/duration.ex
    {time, result} = :timer.tc(:ets, :select, [table, [{match_pattern, [], [:"$1"]}]])
    time_ms = time / :timer.seconds(1)
    Logger.info("#{__MODULE__} fetch predictions #{inspect(opts)} #{time_ms}")
    result
  end

  defp to_record(
         %Prediction{
           id: id,
           # TODO: if we periodic delete based on arrival / departure time,
           # Cancelled trip predictions would stay in the table indefinitely
           # Do we need periodic delete if we are already doing resets?
           # Thought: only need them for streams that are closed. Could actively remove relevant records instead
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

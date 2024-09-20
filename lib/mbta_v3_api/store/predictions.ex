defmodule MBTAV3API.Store.Predictions do
  use GenServer
  require Logger
  alias MBTAV3API.Prediction
  alias MBTAV3API.Store.Predictions

  @behaviour MBTAV3API.Store

  def start_link(opts) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Store.Predictions, Predictions.Impl).start_link(
      opts
    )
  end

  @impl true
  def init(opts) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Store.Predictions, Predictions.Impl).init(
      opts
    )
  end

  @impl true
  def fetch(fetch_keys) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Store.Predictions, Predictions.Impl).fetch(
      fetch_keys
    )
  end

  @impl true
  def fetch_with_associations(fetch_keys) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Store.Predictions, Predictions.Impl).fetch_with_associations(
      fetch_keys
    )
  end

  @impl true
  def process_upsert(event, data) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Store.Predictions, Predictions.Impl).process_upsert(
      event,
      data
    )
  end

  @impl true
  def process_reset(data, scope) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Store.Predictions, Predictions.Impl).process_reset(
      data,
      scope
    )
  end

  @impl true
  def process_remove(references) do
    Application.get_env(:mobile_app_backend, MBTAV3API.Store.Predictions, Predictions.Impl).process_remove(
      references
    )
  end
end

defmodule MBTAV3API.Store.Predictions.Impl do
  @moduledoc """
  Store of predictions. Store is written to by any number of `MBTAV3API.Stream.ConsumerToStore`
  and can be read in parallel by other processes.

  Associated vehicles can be accesssed separately from `MBTAV3!PI.Store.Vehicles`

  Based on https://github.com/mbta/dotcom/blob/main/lib/predictions/store.ex
  """
  use GenServer
  require Logger
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction
  alias MBTAV3API.Store.Vehicles
  alias MBTAV3API.Trip

  @behaviour MBTAV3API.Store

  @predictions_table_name :predictions_from_streams
  @trips_table_name :trips_from_predictions

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    _table = :ets.new(@predictions_table_name, [:named_table, :public, read_concurrency: true])
    _trips_table = :ets.new(@trips_table_name, [:named_table, :public, read_concurrency: true])

    {:ok, %{}}
  end

  @impl true
  def fetch(fetch_keys) do
    if Keyword.keyword?(fetch_keys) do
      match_spec = prediction_match_spec(fetch_keys)

      timed_fetch(
        @predictions_table_name,
        [{match_spec, [], [:"$1"]}],
        "fetch_keys=#{inspect(fetch_keys)}"
      )
    else
      fetch_any(fetch_keys)
    end
  end

  defp fetch_any(fetch_keys_list) do
    match_specs =
      fetch_keys_list
      |> Enum.map(&prediction_match_spec(&1))
      |> Enum.map(&{&1, [], [:"$1"]})

    timed_fetch(
      @predictions_table_name,
      match_specs,
      "multi_fetch=true fetch_keys=#{inspect(fetch_keys_list)}"
    )
  end

  @impl true
  def fetch_with_associations(fetch_keys) do
    predictions = fetch(fetch_keys)

    {trip_fetch_keys_list, vehicle_fetch_keys_list} =
      predictions
      |> Enum.reduce({[], []}, fn prediction, {acc_trip_keys, acc_vehicle_keys} ->
        acc_trip_keys =
          if is_nil(prediction.trip_id),
            do: acc_trip_keys,
            else: [[id: prediction.trip_id] | acc_trip_keys]

        acc_vehicle_keys =
          if is_nil(prediction.vehicle_id),
            do: acc_vehicle_keys,
            else: [[id: prediction.vehicle_id] | acc_vehicle_keys]

        {acc_trip_keys, acc_vehicle_keys}
      end)

    trip_match_specs = Enum.map(trip_fetch_keys_list, &{trip_match_spec(&1), [], [:"$1"]})

    trips =
      timed_fetch(
        @trips_table_name,
        trip_match_specs,
        "fetch_keys=#{inspect(trip_fetch_keys_list)}"
      )

    vehicles = Vehicles.fetch(vehicle_fetch_keys_list)

    JsonApi.Object.to_full_map(predictions ++ trips ++ vehicles)
  end

  defp prediction_match_spec(fetch_keys) do
    # https://www.erlang.org/doc/apps/erts/match_spec.html
    # Match the fields specified in the fetch_keys and return the full prediction
    # see to_record/1 for the defined order of fields
    {
      Keyword.get(fetch_keys, :prediction_id) || :_,
      Keyword.get(fetch_keys, :route_id) || :_,
      Keyword.get(fetch_keys, :stop_id) || :_,
      Keyword.get(fetch_keys, :direction_id) || :_,
      Keyword.get(fetch_keys, :trip_id) || :_,
      Keyword.get(fetch_keys, :vehicle_id) || :_,
      :"$1"
    }
  end

  defp trip_match_spec(fetch_keys) do
    # https://www.erlang.org/doc/apps/erts/match_spec.html
    # Match the fields specified in the fetch_keys and return the full prediction
    # see to_record/1 for the defined order of fields
    {
      Keyword.get(fetch_keys, :id) || :_,
      Keyword.get(fetch_keys, :direction_id) || :_,
      Keyword.get(fetch_keys, :route_id) || :_,
      Keyword.get(fetch_keys, :route_pattern_id) || :_,
      :"$1"
    }
  end

  # Conver the struct to a record for ETS
  defp to_record(
         %Prediction{
           id: id,
           direction_id: direction_id,
           route_id: route_id,
           stop_id: stop_id,
           trip_id: trip_id,
           vehicle_id: vehicle_id
         } = prediction
       ) do
    {
      id,
      route_id,
      stop_id,
      direction_id,
      trip_id,
      vehicle_id,
      prediction
    }
  end

  defp to_record(
         %Trip{
           id: id,
           direction_id: direction_id,
           route_id: route_id,
           route_pattern_id: route_pattern_id
         } = trip
       ) do
    {
      id,
      direction_id,
      route_id,
      route_pattern_id,
      trip
    }
  end

  defp timed_fetch(table_name, match_specs, log_metadata) do
    {time_micros, results} =
      :timer.tc(:ets, :select, [table_name, match_specs])

    time_ms = time_micros / 1000

    Logger.info(
      "#{__MODULE__} fetch table_name=#{table_name} #{log_metadata} duration=#{time_ms}"
    )

    results
  end

  @impl true
  def process_upsert(_event, data) do
    upsert_data(data)
    :ok
  end

  @impl true
  def process_reset(data, scope) do
    clear_data(scope)
    upsert_data(data)
    :ok
  end

  @impl true
  def process_remove(references) do
    for reference <- references do
      case reference do
        %{type: "prediction", id: id} -> :ets.delete(@predictions_table_name, id)
        %{type: "trip", id: id} -> :ets.delete(@trips_table_name, id)
        _ -> :ok
      end
    end

    :ok
  end

  defp upsert_data(data) do
    records_by_type =
      data
      |> Enum.group_by(
        fn data ->
          %data_type{} = data
          data_type
        end,
        fn data -> to_record(data) end
      )

    :ets.insert(@predictions_table_name, Map.get(records_by_type, Prediction, []))
    :ets.insert(@trips_table_name, Map.get(records_by_type, Trip, []))
  end

  defp clear_data(keys) do
    # Since we stream predictions by route, we can clear both the predictions  & route
    # tables by route
    predictions_match_pattern = prediction_match_spec(keys)
    trips_match_pattern = trip_match_spec(keys)

    :ets.select_delete(@predictions_table_name, [{predictions_match_pattern, [], [true]}])
    :ets.select_delete(@trips_table_name, [{trips_match_pattern, [], [true]}])
  end
end

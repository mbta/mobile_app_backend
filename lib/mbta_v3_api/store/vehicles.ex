defmodule MBTAV3API.Store.Vehicles do
  use GenServer
  use MBTAV3API.Store, implementation_module: MBTAV3API.Store.Vehicles.Impl
  require Logger
  alias MBTAV3API.Vehicle
end

defmodule MBTAV3API.Store.Vehicles.Impl do
  @moduledoc """
  Store of vehicles. Store is written to by a single `MBTAV3API.Stream.ConsumerToStore`
  and can be read in parallel by other processes.
  """
  use GenServer
  require Logger
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Store
  alias MBTAV3API.Vehicle

  @behaviour MBTAV3API.Store

  @vehicles_table_name :vehicles_from_stream

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    _table = :ets.new(@vehicles_table_name, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def fetch(fetch_keys) do
    if Keyword.keyword?(fetch_keys) do
      match_spec = vehicle_match_spec(fetch_keys)

      Store.timed_fetch(
        @vehicles_table_name,
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
      |> Enum.map(&vehicle_match_spec(&1))
      |> Enum.map(&{&1, [], [:"$1"]})

    Store.timed_fetch(
      @vehicles_table_name,
      match_specs,
      "multi_fetch=true fetch_keys=#{inspect(fetch_keys_list)}"
    )
  end

  @impl true
  def fetch_with_associations(fetch_keys) do
    vehicles = fetch(fetch_keys)
    JsonApi.Object.to_full_map(vehicles)
  end

  defp vehicle_match_spec(fetch_keys) do
    # https://www.erlang.org/doc/apps/erts/match_spec.html
    # Match the fields specified in the fetch_keys and return the full vehicles
    # see to_record/1 for the defined order of fields
    {
      Keyword.get(fetch_keys, :id) || :_,
      Keyword.get(fetch_keys, :direction_id) || :_,
      Keyword.get(fetch_keys, :route_id) || :_,
      Keyword.get(fetch_keys, :trip_id) || :_,
      :"$1"
    }
  end

  # Conver the struct to a record for ETS
  defp to_record(
         %Vehicle{
           id: id,
           direction_id: direction_id,
           route_id: route_id,
           trip_id: trip_id
         } = vehicle
       ) do
    {
      id,
      direction_id,
      route_id,
      trip_id,
      vehicle
    }
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
        %{type: "vehicle", id: id} -> :ets.delete(@vehicles_table_name, id)
        _ -> :ok
      end
    end

    :ok
  end

  defp upsert_data(vehicles) do
    records = Enum.map(vehicles, &to_record(&1))

    :ets.insert(@vehicles_table_name, records)
  end

  defp clear_data(keys) do
    vehicles_match_pattern = vehicle_match_spec(keys)
    :ets.select_delete(@vehicles_table_name, [{vehicles_match_pattern, [], [true]}])
  end
end

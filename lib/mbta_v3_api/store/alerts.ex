defmodule MBTAV3API.Store.Alerts do
  use GenServer
  use MBTAV3API.Store, implementation_module: MBTAV3API.Store.Alerts.Impl
  require Logger
  alias MBTAV3API.Alert
end

defmodule MBTAV3API.Store.Alerts.Impl do
  @moduledoc """
  Store of alerts. Store is written to by a single `MBTAV3API.Stream.ConsumerToStore`
  and can be read in parallel by other processes.
  """
  use GenServer
  require Logger
  alias MBTAV3API.Alert

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Store

  @behaviour MBTAV3API.Store

  @alerts_table_name :alerts_from_stream

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    _table = :ets.new(@alerts_table_name, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def fetch(fetch_keys) do
    if Keyword.keyword?(fetch_keys) do
      match_spec = alert_match_spec(fetch_keys)

      Store.timed_fetch(
        @alerts_table_name,
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
      |> Enum.map(&alert_match_spec(&1))
      |> Enum.map(&{&1, [], [:"$1"]})

    Store.timed_fetch(
      @alerts_table_name,
      match_specs,
      "multi_fetch=true fetch_keys=#{inspect(fetch_keys_list)}"
    )
  end

  @impl true
  def fetch_with_associations(fetch_keys) do
    data = fetch(fetch_keys)
    JsonApi.Object.to_full_map(data)
  end

  defp alert_match_spec(fetch_keys) do
    # https://www.erlang.org/doc/apps/erts/match_spec.html
    # Match the fields specified in the fetch_keys and return the full alerts
    # see to_record/1 for the defined order of fields
    {
      Keyword.get(fetch_keys, :id) || :_,
      :"$1"
    }
  end

  # override alert 611483 behavior to temporarily address GL Park St alert boundary issue
  defp to_record(
         %Alert{
           id: "611483"
         } = alert
       ) do
    entities =
      alert.informed_entity
      |> Enum.reject(fn entity ->
        (entity.stop == "70196" && entity.route != "Green-B") ||
          (entity.stop == "70197" && entity.route != "Green-C") ||
          (entity.stop == "70198" && entity.route != "Green-D") ||
          (entity.stop == "70199" && entity.route != "Green-E")
      end)

    {
      "611483",
      %{alert | informed_entity: entities}
    }
  end

  # Convert the struct to a record for ETS
  defp to_record(
         %Alert{
           id: id
         } = alert
       ) do
    {
      id,
      alert
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
        %{type: "alert", id: id} -> :ets.delete(@alerts_table_name, id)
        _ -> :ok
      end
    end

    :ok
  end

  defp upsert_data(api_records) do
    records = Enum.map(api_records, &to_record(&1))

    :ets.insert(@alerts_table_name, records)
  end

  defp clear_data(keys) do
    match_pattern = alert_match_spec(keys)
    :ets.select_delete(@alerts_table_name, [{match_pattern, [], [true]}])
  end
end

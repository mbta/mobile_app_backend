defmodule MBTAV3API.StoreTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Test.Support.Helpers

  alias MBTAV3API.Store

  defmodule TestTableOwner do
    use GenServer
    @spec start_link(Keyword.t()) :: GenServer.on_start()
    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    @impl true
    def init(_) do
      _table = :ets.new(:test_table, [:named_table, :public, read_concurrency: true])
      {:ok, %{}}
    end
  end

  setup do
    start_link_supervised!(TestTableOwner)
    :ok
  end

  describe "timed_fetch/3" do
    test "returns matches & logs duration" do
      set_log_level(:info)
      :ets.insert(:test_table, [{"key", "value"}, {"other", "other_value"}])

      {results, log} =
        with_log([level: :info], fn ->
          Store.timed_fetch(:test_table, [{{"key", :"$1"}, [], [:"$1"]}], "other_field=true")
        end)

      assert ["value"] == results

      assert log =~
               "fetch table_name=test_table other_field=true duration="
    end
  end
end

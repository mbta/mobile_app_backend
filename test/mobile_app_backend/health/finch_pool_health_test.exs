defmodule MobileAppBackend.Health.FinchPoolTest do
  use ExUnit.Case
  alias MobileAppBackend.Health.FinchPool
  import ExUnit.CaptureLog
  import Test.Support.Helpers

  describe "handle_info/1" do
    test "when pool not found yet, logs error" do
      set_log_level(:info)

      msg =
        capture_log(fn ->
          FinchPool.handle_info(:check, %{
            pool_name: "test_pool",
            get_pool_status_fn: fn _, _ -> {:error, :not_found} end
          })
        end)

      assert msg =~ "pool not found"
    end

    test "when error, logs warning" do
      set_log_level(:warning)

      msg =
        capture_log(fn ->
          FinchPool.handle_info(:check, %{
            pool_name: "test_pool",
            get_pool_status_fn: fn _, _ -> {:error, :other_error} end
          })
        end)

      assert msg =~ "error=:other_error"
    end

    test "when pools found, logs status" do
      set_log_level(:info)

      status = %{available_connections: 5, in_use_connections: 10, pool_index: 1, pool_size: 15}

      msg =
        capture_log(fn ->
          FinchPool.handle_info(:check, %{
            pool_name: "test_pool",
            get_pool_status_fn: fn _, _ -> {:ok, [status]} end
          })
        end)

      assert msg =~
               "pool_health available_connections=#{status.available_connections} in_use_connections=#{status.in_use_connections} pool_index=#{status.pool_index} pool_size=#{status.pool_size}"
    end
  end
end

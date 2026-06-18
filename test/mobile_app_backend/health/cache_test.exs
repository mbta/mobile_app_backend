defmodule MobileAppBackend.Health.CacheTest do
  use ExUnit.Case
  alias MobileAppBackend.Health
  import ExUnit.CaptureLog
  import Test.Support.Helpers

  defmodule Cache do
    def stats do
      %Nebulex.Stats{measurements: %{hits: 4, misses: 4}}
    end
  end

  defmodule StatslessCache do
    def stats, do: nil
  end

  describe "handle_info/1" do
    test "when stats disabled, logs" do
      set_log_level(:info)

      msg =
        capture_log(fn ->
          Health.Cache.handle_info(:check, %{cache: StatslessCache})
        end)

      assert msg =~ "cache=#{StatslessCache} cache stats disabled"
    end

    test "when stats found, logs stats" do
      set_log_level(:info)

      msg =
        capture_log(fn ->
          Health.Cache.handle_info(:check, %{cache: Cache})
        end)

      assert msg =~ "cache=#{Cache} cache_health hits=4 misses=4 hit_rate=0.5"
    end
  end
end

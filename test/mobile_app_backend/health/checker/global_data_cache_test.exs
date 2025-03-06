defmodule MobileAppBackend.Health.Checker.GlobalDataCacheTest do
  @moduledoc false
  use ExUnit.Case

  alias MobileAppBackend.Health.Checker.GlobalDataCache, as: Checker

  import ExUnit.CaptureLog
  import Mox
  import Test.Support.Helpers

  describe "check_health/0" do
    setup do
      verify_on_exit!()

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.GlobalDataCache.Module,
        GlobalDataCacheMock
      )

      expect(GlobalDataCacheMock, :default_key, fn -> :default_key end)

      :ok
    end

    test "defaults to false" do
      expect(GlobalDataCacheMock, :get_data, fn :default_key -> nil end)

      set_log_level(:warning)

      msg =
        capture_log(fn ->
          assert {:error, "cached data was nil"} = Checker.check_health()
        end)

      assert msg =~
               "Health check failed for Elixir.MobileAppBackend.Health.Checker.GlobalDataCache: cached data was nil"
    end

    test "returns true after global data cache has loaded" do
      expect(GlobalDataCacheMock, :get_data, fn :default_key -> :some_data end)

      assert :ok = Checker.check_health()
    end
  end
end

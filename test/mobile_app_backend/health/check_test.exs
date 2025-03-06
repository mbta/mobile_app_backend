defmodule MobileAppBackend.Health.CheckTest do
  @moduledoc false
  use ExUnit.Case

  alias MobileAppBackend.Health.Check
  alias MobileAppBackend.Health.Checker

  import ExUnit.CaptureLog
  import Mox
  import Test.Support.Helpers

  describe "healthy?/0" do
    setup do
      verify_on_exit!()

      reassign_env(:mobile_app_backend, Checker.Alerts, AlertsCheckerMock)
      reassign_env(:mobile_app_backend, Checker.GlobalDataCache, GlobalDataCacheCheckerMock)

      :ok
    end

    test "fails if any checks fail" do
      expect(AlertsCheckerMock, :check_health, fn -> :ok end)
      set_log_level(:warning)

      expect(GlobalDataCacheCheckerMock, :check_health, fn -> {:error, "bad cache"} end)

      msg =
        capture_log(fn ->
          refute Check.healthy?()
        end)

      assert msg =~
               "Health check failed for Elixir.MobileAppBackend.Health.Checker.GlobalDataCache: bad cache"
    end

    test "returns true if all checks pass" do
      expect(AlertsCheckerMock, :check_health, fn -> :ok end)
      expect(GlobalDataCacheCheckerMock, :check_health, fn -> :ok end)

      assert Check.healthy?()
    end
  end
end

defmodule MobileAppBackend.Health.Checker.OverallTest do
  @moduledoc false
  use ExUnit.Case

  alias MobileAppBackend.Health.Checker

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
      expect(AlertsCheckerMock, :healthy?, fn -> true end)
      expect(GlobalDataCacheCheckerMock, :healthy?, fn -> false end)

      refute Checker.Overall.healthy?()
    end

    test "returns true if all checks pass" do
      expect(AlertsCheckerMock, :healthy?, fn -> true end)
      expect(GlobalDataCacheCheckerMock, :healthy?, fn -> true end)

      assert Checker.Overall.healthy?()
    end
  end
end

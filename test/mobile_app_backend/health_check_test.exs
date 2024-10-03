defmodule MobileAppBackend.HealthCheckTest do
  @moduledoc false
  use ExUnit.Case
  alias MobileAppBackend.HealthCheck
  import Mox
  import Test.Support.Helpers

  describe "healthy?/0" do
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

      refute HealthCheck.healthy?()
    end

    test "returns true after global data cache has loaded" do
      expect(GlobalDataCacheMock, :get_data, fn :default_key -> :some_data end)

      assert HealthCheck.healthy?()
    end
  end
end

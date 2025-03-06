defmodule MobileAppBackend.Health.Checker.GlobalDataCache do
  use MobileAppBackend.Health.Checker,
    implementation_module: MobileAppBackend.Health.Checker.GlobalDataCache.Impl
end

defmodule MobileAppBackend.Health.Checker.GlobalDataCache.Impl do
  @moduledoc """
  Check if the global data cache is populated with data
  """

  alias MobileAppBackend.GlobalDataCache
  @behaviour MobileAppBackend.Health.Checker

  @impl true
  def check_health do
    if GlobalDataCache.get_data() != nil do
      :ok
    else
      {:error, "cached data was nil"}
    end
  end
end

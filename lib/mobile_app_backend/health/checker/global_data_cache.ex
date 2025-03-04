defmodule MobileAppBackend.Health.Checker.GlobalDataCache do
  use MobileAppBackend.Health.Checker,
    implementation_module: MobileAppBackend.Health.Checker.GlobalDataCache.Impl
end

defmodule MobileAppBackend.Health.Checker.GlobalDataCache.Impl do
  @moduledoc """
  Check if the global data cache is populated with data
  """

  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Health.Checker.GlobalDataCache, as: Checker
  @behaviour MobileAppBackend.Health.Checker

  @impl true
  def healthy? do
    Checker.log_failure(GlobalDataCache.get_data() != nil, "cached data was nil")
  end
end

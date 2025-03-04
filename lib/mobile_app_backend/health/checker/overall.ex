defmodule MobileAppBackend.Health.Checker.Overall do
  use MobileAppBackend.Health.Checker,
    implementation_module: MobileAppBackend.Health.Checker.Overall.Impl
end

defmodule MobileAppBackend.Health.Checker.Overall.Impl do
  @moduledoc """
  Checks whether the application is healthy.
  """

  alias MobileAppBackend.Health.Checker
  @behaviour MobileAppBackend.Health.Checker

  @doc """
  Returns true if the application is healthy.

  Don't log failures here, since each basic checker should be handling that.
  """
  @impl true
  def healthy? do
    Enum.all?(
      Task.await_many([
        Task.async(fn -> Checker.Alerts.healthy?() end),
        Task.async(fn -> Checker.GlobalDataCache.healthy?() end)
      ])
    )
  end
end

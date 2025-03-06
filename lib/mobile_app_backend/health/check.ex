defmodule MobileAppBackend.Health.Check do
  @moduledoc """
  Checks whether the application is healthy.
  """

  alias MobileAppBackend.Health.Checker

  @doc """
  Returns true if all Checkers are healthy.
  """
  @spec healthy?() :: boolean()
  def healthy? do
    Enum.all?(
      Task.await_many([
        Task.async(fn -> Checker.Alerts.check_health() end),
        Task.async(fn -> Checker.GlobalDataCache.check_health() end)
      ]),
      fn result ->
        case result do
          :ok -> true
          _ -> false
        end
      end
    )
  end
end

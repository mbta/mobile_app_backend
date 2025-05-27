defmodule MobileAppBackend.Health.Check do
  @moduledoc """
  Checks whether the application is healthy.
  """

  alias MobileAppBackend.Health.Checker

  require Logger

  @doc """
  Returns true if all Checkers are healthy.
  """
  @spec healthy?() :: boolean()
  def healthy?(timeout \\ 10_000) do
    Enum.all?(
      Task.await_many(
        [
          Task.async(fn -> Checker.Alerts.check_health() end),
          Task.async(fn -> Checker.GlobalDataCache.check_health() end)
        ],
        timeout
      ),
      fn result ->
        case result do
          :ok -> true
          _ -> false
        end
      end
    )
  catch
    :exit, {:timeout, _} ->
      Logger.warning("#{__MODULE__} health_check_timeout")
      false
  end
end

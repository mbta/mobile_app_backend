defmodule MobileAppBackend.Health.Checker.Alerts do
  use MobileAppBackend.Health.Checker,
    implementation_module: MobileAppBackend.Health.Checker.Alerts.Impl
end

defmodule MobileAppBackend.Health.Checker.Alerts.Impl do
  @moduledoc """
  Check if the number of alerts returned from the backend matches
  the number we have saved in the store
  """

  alias MBTAV3API.Repository
  alias MBTAV3API.Store

  @behaviour MobileAppBackend.Health.Checker

  @impl true
  def check_health do
    store_count = length(Store.Alerts.fetch([]))

    case Repository.alerts([]) do
      {:ok, %{data: repo_alerts}} ->
        repo_count = length(repo_alerts)

        if store_count == repo_count do
          :ok
        else
          {:error, "stored alert count #{store_count} != backend alert count #{repo_count}"}
        end

      _ ->
        {:error, "backend alert request failed"}
    end
  end
end

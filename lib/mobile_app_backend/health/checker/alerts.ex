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
  alias MobileAppBackend.Health.Checker.Alerts.LastFreshStore

  require Logger

  @behaviour MobileAppBackend.Health.Checker

  @grace_period 300

  @impl true
  def check_health do
    store_count = length(Store.Alerts.fetch(fields: [alert: []]))

    case Repository.alerts([]) do
      {:ok, %{data: repo_alerts}} ->
        repo_count = length(repo_alerts)

        if store_count == repo_count do
          LastFreshStore.update_last_fresh_timestamp()
          :ok
        else
          evaluate_alert_data_freshness(
            "stored_alert_count=#{store_count} backend_alert_count=#{repo_count}"
          )
        end

      _ ->
        Logger.warning(
          "#{__MODULE__} V3 API request for alerts failed, couldn't check freshness of alerts in Store.Alerts"
        )

        evaluate_alert_data_freshness(
          "stored_alert_count=#{store_count} backend_alert_count=unable_to_fetch"
        )
    end
  end

  defp evaluate_alert_data_freshness(log_context) do
    last_fresh_timestamp = LastFreshStore.last_fresh_timestamp()
    now = DateTime.utc_now()

    if DateTime.diff(now, last_fresh_timestamp) > @grace_period do
      {:error, "#{log_context} last_fresh_timestamp=#{last_fresh_timestamp}"}
    else
      :ok
    end
  end
end

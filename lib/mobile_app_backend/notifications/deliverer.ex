defmodule MobileAppBackend.Notifications.Deliverer do
  use Oban.Worker, unique: [period: :infinity]
  require Logger
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Repo

  @impl true
  def perform(%Oban.Job{
        args: %{
          "user_id" => user_id,
          "alert_id" => alert_id,
          "upstream_timestamp" => upstream_timestamp
        }
      }) do
    {:ok, upstream_timestamp, _} = DateTime.from_iso8601(upstream_timestamp)
    Logger.info("#{__MODULE__} sending alert #{alert_id} to user #{user_id}")

    Repo.insert!(%DeliveredNotification{
      user_id: user_id,
      alert_id: alert_id,
      upstream_timestamp: upstream_timestamp
    })

    :ok
  end
end

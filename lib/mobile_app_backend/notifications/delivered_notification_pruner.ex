defmodule MobileAppBackend.Notifications.DeliveredNotificationPruner do
  use Oban.Worker
  import Ecto.Query
  require Logger
  alias MBTAV3API.Store
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    current_alert_ids = current_alert_ids()

    # if the alerts feed is empty, that’s more likely to mean that there’s a data outage somewhere than
    # that all alerts have been closed, so wait for the alerts to populate
    if current_alert_ids == [] do
      {:snooze, 60}
    else
      one_week_ago = DateTime.utc_now(:second) |> DateTime.shift(week: -1)

      {count, _} =
        Repo.delete_all(
          from dn in DeliveredNotification,
            where: dn.alert_id not in ^current_alert_ids and dn.inserted_at < ^one_week_ago
        )

      Logger.info("#{__MODULE__} pruned=#{count}")
      :ok
    end
  end

  defp current_alert_ids do
    Store.Alerts.fetch([]) |> Enum.map(& &1.id)
  end
end

defmodule MobileAppBackend.Notifications.DelivererTest do
  use MobileAppBackend.DataCase, async: true
  use Oban.Testing, repo: MobileAppBackend.Repo
  alias MobileAppBackend.Factory
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.NotificationsFactory

  test "marks notification as delivered" do
    user = NotificationsFactory.insert(:user)
    user_id = user.id
    alert = Factory.build(:alert)
    alert_id = alert.id
    upstream_timestamp = DateTime.utc_now(:second)

    :ok =
      perform_job(Notifications.Deliverer, %{
        user_id: user_id,
        alert_id: alert_id,
        upstream_timestamp: upstream_timestamp
      })

    assert [
             %DeliveredNotification{
               user_id: ^user_id,
               alert_id: ^alert_id,
               upstream_timestamp: ^upstream_timestamp
             }
           ] = Repo.all(DeliveredNotification)
  end
end

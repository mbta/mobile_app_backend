defmodule MobileAppBackend.Notifications.DelivererTest do
  use MobileAppBackend.DataCase, async: false
  use Oban.Testing, repo: MobileAppBackend.Repo
  import ExUnit.CaptureLog
  import Mox
  import Tesla.Test
  import Test.Support.Helpers
  alias MBTAV3API.Store.Alerts
  alias MobileAppBackend.Factory
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.GCPToken
  alias MobileAppBackend.NotificationsFactory

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "delivers notification via FCM and marks notification as delivered" do
    start_link_supervised!(Alerts)
    user = NotificationsFactory.insert(:user)
    user_id = user.id
    fcm_token = user.fcm_token
    alert = Factory.build(:alert)
    Alerts.process_reset([alert], [])
    alert_id = alert.id
    upstream_timestamp = DateTime.utc_now(:second)

    reassign_persistent_term(GCPToken.default_key(), %GCPToken.StoredToken{
      token: "gcp_token",
      expires: ~U[9999-12-31 23:59:59Z]
    })

    reassign_env(:tesla, :adapter, TeslaMockAdapter)

    expect_tesla_call(
      times: 1,
      returns: %Tesla.Env{status: 200} |> json(%{}),
      adapter: TeslaMockAdapter
    )

    :ok =
      perform_job(Notifications.Deliverer, %{
        user_id: user_id,
        alert_id: alert_id,
        upstream_timestamp: upstream_timestamp
      })

    assert_received_tesla_call(received_env, received_opts, adapter: TeslaMockAdapter)

    assert %Tesla.Env{
             method: :post,
             url: "https://fcm.googleapis.com/v1/projects/mbta-app-c574d/messages:send",
             headers: [
               {"x-goog-api-client", _},
               {"authorization", "Bearer gcp_token"},
               {"accept-encoding", "gzip, deflate, identity"},
               {"content-type", "application/json"}
             ],
             body: received_body
           } = received_env

    assert %{
             message: %{
               notification: %{title: "Alert " <> ^alert_id, body: "Hello we are your bus"},
               token: ^fcm_token
             }
           } = Jason.decode!(received_body, keys: :atoms!)

    assert [] = received_opts

    assert [
             %DeliveredNotification{
               user_id: ^user_id,
               alert_id: ^alert_id,
               upstream_timestamp: ^upstream_timestamp
             }
           ] = Repo.all(DeliveredNotification)

    assert DateTime.before?(user.fcm_last_verified, Repo.reload!(user).fcm_last_verified)
  end

  test "does not update FCM last verified if notification fails to deliver" do
    start_link_supervised!(Alerts)
    user = NotificationsFactory.insert(:user)
    user_id = user.id
    alert = Factory.build(:alert)
    Alerts.process_reset([alert], [])
    alert_id = alert.id
    upstream_timestamp = DateTime.utc_now(:second)

    reassign_persistent_term(GCPToken.default_key(), %GCPToken.StoredToken{
      token: "gcp_token",
      expires: ~U[9999-12-31 23:59:59Z]
    })

    reassign_env(:tesla, :adapter, TeslaMockAdapter)

    expect_tesla_call(
      times: 1,
      returns: %Tesla.Env{status: 418} |> json(%{}),
      adapter: TeslaMockAdapter
    )

    {:ok, _} =
      with_log(fn ->
        perform_job(Notifications.Deliverer, %{
          user_id: user_id,
          alert_id: alert_id,
          upstream_timestamp: upstream_timestamp
        })
      end)

    assert [
             %DeliveredNotification{
               user_id: ^user_id,
               alert_id: ^alert_id,
               upstream_timestamp: ^upstream_timestamp
             }
           ] = Repo.all(DeliveredNotification)

    assert user.fcm_last_verified == Repo.reload!(user).fcm_last_verified
  end
end

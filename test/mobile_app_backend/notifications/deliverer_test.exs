defmodule MobileAppBackend.Notifications.DelivererTest do
  use MobileAppBackend.DataCase, async: false
  use Oban.Testing, repo: MobileAppBackend.Repo
  import ExUnit.CaptureLog
  import Mox
  import Tesla.Test
  import Test.Support.Helpers
  alias MBTAV3API.Store.Alerts
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Factory
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.GCPToken
  alias MobileAppBackend.NotificationsFactory
  alias MobileAppBackend.User

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
    type = :notification

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
        summary: %AlertSummary{
          effect: :station_closure,
          location: %AlertSummary.Location.SingleStop{stop_name: "South Station"},
          timeframe: %AlertSummary.Timeframe.Tomorrow{}
        },
        upstream_timestamp: upstream_timestamp,
        type: type
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
               data: %{
                 summary: %{
                   effect: "station_closure",
                   location: %{type: "single_stop", stop_name: "South Station"},
                   timeframe: %{type: "tomorrow"}
                 }
               },
               token: ^fcm_token
             }
           } = Jason.decode!(received_body, keys: :atoms!)

    assert [] = received_opts

    assert [
             %DeliveredNotification{
               user_id: ^user_id,
               alert_id: ^alert_id,
               upstream_timestamp: ^upstream_timestamp,
               type: ^type
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
    type = :notification

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
          summary: %AlertSummary{},
          upstream_timestamp: upstream_timestamp,
          type: type
        })
      end)

    assert [
             %DeliveredNotification{
               user_id: ^user_id,
               alert_id: ^alert_id,
               upstream_timestamp: ^upstream_timestamp,
               type: ^type
             }
           ] = Repo.all(DeliveredNotification)

    assert user.fcm_last_verified == Repo.reload!(user).fcm_last_verified
  end

  test "deletes user if FCM returns 404" do
    start_link_supervised!(Alerts)
    user = NotificationsFactory.insert(:user)
    NotificationsFactory.insert(:notification_subscription, user: user)
    user_id = user.id
    alert = Factory.build(:alert)
    Alerts.process_reset([alert], [])
    alert_id = alert.id
    upstream_timestamp = DateTime.utc_now(:second)
    type = :notification

    reassign_persistent_term(GCPToken.default_key(), %GCPToken.StoredToken{
      token: "gcp_token",
      expires: ~U[9999-12-31 23:59:59Z]
    })

    reassign_env(:tesla, :adapter, TeslaMockAdapter)

    expect_tesla_call(
      times: 1,
      returns: %Tesla.Env{status: 404} |> json(%{}),
      adapter: TeslaMockAdapter
    )

    {:ok, _} =
      with_log(fn ->
        perform_job(Notifications.Deliverer, %{
          user_id: user_id,
          alert_id: alert_id,
          summary: %AlertSummary{},
          upstream_timestamp: upstream_timestamp,
          type: type
        })
      end)

    assert [] = Repo.all(DeliveredNotification)
    assert [] = Repo.all(User)
    assert [] = Repo.all(Notifications.Subscription)
  end
end

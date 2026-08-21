defmodule MobileAppBackend.Notifications.DelivererTest do
  use MobileAppBackend.DataCase, async: false
  use Oban.Testing, repo: MobileAppBackend.Repo
  import ExUnit.CaptureLog
  import Mox
  import Test.Support.Helpers
  alias MBTAV3API.Store.Alerts
  alias MobileAppBackend.Factory
  alias MobileAppBackend.Notifications
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.GCPToken
  alias MobileAppBackend.NotificationsFactory
  alias MobileAppBackend.User

  setup :set_mox_from_context
  setup :verify_on_exit!
  setup {Req.Test, :verify_on_exit!}

  test "delivers notification via FCM with new installation ID and marks notification as delivered" do
    start_link_supervised!(Alerts)
    user = NotificationsFactory.insert(:user)
    user_id = user.id
    fcm_installation_id = user.fcm_installation_id
    alert = Factory.build(:alert)
    Alerts.process_reset([alert], [])
    alert_id = alert.id
    upstream_timestamp = DateTime.utc_now(:second)
    type = :notification

    title = "Notification title"
    body = "Notification body"
    deep_link_path = "/a/#{alert_id}/r/1/s/1"
    analytics_label = "route=1;effect=delay;type=notification"

    reassign_persistent_term(GCPToken.default_key(), %GCPToken.StoredToken{
      token: "gcp_token",
      expires: ~U[9999-12-31 23:59:59Z]
    })

    Req.Test.expect(Util.GCP, fn conn ->
      assert conn.method == "POST"

      assert Plug.Conn.request_url(conn) ==
               "https://fcm.googleapis.com/v1/projects/mbta-app-c574d/messages:send"

      assert [
               {"accept", "application/json"},
               {"authorization", "Bearer gcp_token"},
               {"content-type", "application/json"},
               {"user-agent", "req/" <> _}
             ] = Enum.sort(conn.req_headers)

      assert conn.body_params == %{
               "message" => %{
                 "token" => nil,
                 "fid" => fcm_installation_id,
                 "notification" => %{"title" => title, "body" => body},
                 "data" => %{
                   "deep_link_path" => deep_link_path,
                   "analytics_label" => analytics_label
                 },
                 "android" => %{
                   "notification" => %{
                     "tag" => alert_id,
                     "sound" => "default",
                     "visibility" => "public"
                   }
                 },
                 "apns" => %{"payload" => %{"aps" => %{"sound" => "default"}}},
                 "fcm_options" => %{"analytics_label" => analytics_label}
               }
             }

      Req.Test.json(conn, %{})
    end)

    :ok =
      perform_job(Notifications.Deliverer, %{
        user_id: user_id,
        alert_id: alert_id,
        title: title,
        body: body,
        deep_link_path: deep_link_path,
        upstream_timestamp: upstream_timestamp,
        type: type,
        analytics_label: analytics_label
      })

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

  test "delivers notification via FCM with old token and marks notification as delivered" do
    start_link_supervised!(Alerts)
    user = NotificationsFactory.insert(:user_with_old_token)
    user_id = user.id
    fcm_token = user.fcm_token
    alert = Factory.build(:alert)
    Alerts.process_reset([alert], [])
    alert_id = alert.id
    upstream_timestamp = DateTime.utc_now(:second)
    type = :notification

    title = "Notification title"
    body = "Notification body"
    deep_link_path = "/a/#{alert_id}/r/1/s/1"
    analytics_label = "route=1;effect=delay;type=notification"

    reassign_persistent_term(GCPToken.default_key(), %GCPToken.StoredToken{
      token: "gcp_token",
      expires: ~U[9999-12-31 23:59:59Z]
    })

    Req.Test.expect(Util.GCP, fn conn ->
      assert conn.method == "POST"

      assert Plug.Conn.request_url(conn) ==
               "https://fcm.googleapis.com/v1/projects/mbta-app-c574d/messages:send"

      assert [
               {"accept", "application/json"},
               {"authorization", "Bearer gcp_token"},
               {"content-type", "application/json"},
               {"user-agent", "req/" <> _}
             ] = Enum.sort(conn.req_headers)

      assert conn.body_params == %{
               "message" => %{
                 "token" => fcm_token,
                 "fid" => nil,
                 "notification" => %{"title" => title, "body" => body},
                 "data" => %{
                   "deep_link_path" => deep_link_path,
                   "analytics_label" => analytics_label
                 },
                 "android" => %{
                   "notification" => %{
                     "tag" => alert_id,
                     "sound" => "default",
                     "visibility" => "public"
                   }
                 },
                 "apns" => %{
                   "payload" => %{"aps" => %{"sound" => "default", "thread-id" => alert_id}}
                 },
                 "fcm_options" => %{"analytics_label" => analytics_label}
               }
             }

      Req.Test.json(conn, %{})
    end)

    :ok =
      perform_job(Notifications.Deliverer, %{
        user_id: user_id,
        alert_id: alert_id,
        title: title,
        body: body,
        deep_link_path: deep_link_path,
        upstream_timestamp: upstream_timestamp,
        type: type,
        analytics_label: analytics_label
      })

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

    title = "Notification title"
    body = "Notification body"
    deep_link_path = "/a/#{alert_id}/r/1/s/1"
    analytics_label = "route=1;effect=delay;type=notification"

    reassign_persistent_term(GCPToken.default_key(), %GCPToken.StoredToken{
      token: "gcp_token",
      expires: ~U[9999-12-31 23:59:59Z]
    })

    Req.Test.expect(Util.GCP, fn conn ->
      conn |> Plug.Conn.put_status(418) |> Req.Test.json(%{})
    end)

    {{:cancel, :error}, _} =
      with_log(fn ->
        perform_job(Notifications.Deliverer, %{
          user_id: user_id,
          alert_id: alert_id,
          title: title,
          body: body,
          deep_link_path: deep_link_path,
          upstream_timestamp: upstream_timestamp,
          type: type,
          analytics_label: analytics_label
        })
      end)

    assert [] = Repo.all(DeliveredNotification)

    assert user.fcm_last_verified == Repo.reload!(user).fcm_last_verified
  end

  test "deletes user if FCM returns 404" do
    start_link_supervised!(Alerts)
    user = NotificationsFactory.insert(:user)
    NotificationsFactory.insert(:notification_subscription, user_id: user.id)
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

    Req.Test.expect(Util.GCP, fn conn ->
      conn |> Plug.Conn.put_status(:not_found) |> Req.Test.json(%{})
    end)

    {:ok, _} =
      with_log(fn ->
        perform_job(Notifications.Deliverer, %{
          user_id: user_id,
          alert_id: alert_id,
          title: "title",
          body: "body",
          deep_link_path: "/a/#{alert_id}/r/1/s/1",
          upstream_timestamp: upstream_timestamp,
          type: type,
          analytics_label: "route=1;effect=delay;type=notification"
        })
      end)

    assert [] = Repo.all(DeliveredNotification)
    assert [] = Repo.all(User)
    assert [] = Repo.all(Notifications.Subscription)
  end

  test "deletes user if APNs returns 410" do
    start_link_supervised!(Alerts)
    user = NotificationsFactory.insert(:user)
    NotificationsFactory.insert(:notification_subscription, user_id: user.id)
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

    Req.Test.expect(Util.GCP, fn conn ->
      conn
      |> Plug.Conn.put_status(:bad_request)
      |> Req.Test.json(%{
        "error" => %{
          "code" => 400,
          "details" => [
            %{
              "@type" => "type.googleapis.com/google.firebase.fcm.v1.FcmError",
              "errorCode" => "INVALID_ARGUMENT"
            },
            %{
              "@type" => "type.googleapis.com/google.firebase.fcm.v1.ApnsError",
              "reason" => "Unregistered",
              "statusCode" => 410
            }
          ],
          "message" => "APNs device token is disabled.",
          "status" => "INVALID_ARGUMENT"
        }
      })
    end)

    {:ok, _} =
      with_log(fn ->
        perform_job(Notifications.Deliverer, %{
          user_id: user_id,
          alert_id: alert_id,
          title: "title",
          body: "body",
          deep_link_path: "/a/#{alert_id}/r/1/s/1",
          upstream_timestamp: upstream_timestamp,
          type: type,
          analytics_label: "route=1;effect=delay;type=notification"
        })
      end)

    assert [] = Repo.all(DeliveredNotification)
    assert [] = Repo.all(User)
    assert [] = Repo.all(Notifications.Subscription)
  end
end

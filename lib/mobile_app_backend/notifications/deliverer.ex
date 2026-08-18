defmodule MobileAppBackend.Notifications.Deliverer do
  use Oban.Worker, unique: [period: :infinity], max_attempts: 4
  require Logger
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.GCPToken
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User
  alias Util.GCP.FCM

  @impl true
  def perform(%Oban.Job{
        args: %{
          "user_id" => user_id,
          "alert_id" => alert_id,
          "title" => title,
          "body" => body,
          "deep_link_path" => deep_link_path,
          "upstream_timestamp" => upstream_timestamp,
          "type" => type,
          "analytics_label" => analytics_label
        }
      }) do
    upstream_timestamp =
      if is_nil(upstream_timestamp) do
        nil
      else
        {:ok, upstream_timestamp, _} = DateTime.from_iso8601(upstream_timestamp)
        upstream_timestamp
      end

    {:ok, type} = Ecto.Enum.cast_value(DeliveredNotification, :type, type)

    Logger.info("#{__MODULE__} sending alert #{alert_id} to user #{user_id}")

    user = Repo.get!(User, user_id)

    gcp_token = GCPToken.get_token()

    # in Android, a notification with a tag will replace an old notification with the same tag
    tag =
      case type do
        :all_clear -> "#{alert_id}-all-clear"
        _ -> alert_id
      end

    request_body = %{
      message: %FCM.Message{
        notification: %FCM.Notification{
          title: title,
          body: body
        },
        data: %{"deep_link_path" => deep_link_path, "analytics_label" => analytics_label},
        android: %FCM.AndroidConfig{
          notification: %FCM.AndroidNotification{
            sound: "default",
            tag: tag,
            visibility: :public
          }
        },
        apns: %FCM.ApnsConfig{
          payload: %{
            aps: %{sound: "default", "thread-id": alert_id}
          }
        },
        fcm_options: %FCM.FcmOptions{
          analytics_label: analytics_label
        },
        token: user.fcm_token
      }
    }

    result =
      FCM.send(
        gcp_token,
        "projects/mbta-app-c574d",
        request_body
      )
      |> handle_fcm_response(user)

    Logger.info(
      "#{__MODULE__} notification_sent result=#{result} type=#{type} alert_id=#{alert_id}"
    )

    # This section is only to allow Android to group notifications, it gets ignored by iOS
    data_request_body = %{
      message: %FCM.Message{
        data: %{alert_id: alert_id, title: title, body: body},
        fcm_options: %FCM.FcmOptions{
          analytics_label: analytics_label
        },
        token: user.fcm_token
      }
    }

    data_notification_result =
      FCM.send(
        gcp_token,
        "projects/mbta-app-c574d",
        data_request_body
      )
      |> handle_fcm_response(user)

    Logger.info(
      "#{__MODULE__} data_notification_sent result=#{data_notification_result} type=#{type} alert_id=#{alert_id}"
    )

    case result do
      :ok ->
        Repo.insert!(%DeliveredNotification{
          user_id: user_id,
          alert_id: alert_id,
          upstream_timestamp: upstream_timestamp,
          type: type
        })

        :ok

      :deleted ->
        :ok

      :error ->
        # if we let Oban own the retry, the notification may not still be
        # worth sending by the time it succeeds, so we leave it to the
        # scheduler to retry the notification, and we mark this job as
        # cancelled so the retry doesn’t count as a duplicate
        {:cancel, :error}
    end
  end

  defp handle_fcm_response({:ok, %Req.Response{status: status}}, user) when status in 200..299 do
    user
    |> Ecto.Changeset.change(fcm_last_verified: DateTime.utc_now(:second))
    |> Repo.update()
    |> case do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error(inspect(error))
        :error
    end
  end

  defp handle_fcm_response({:ok, %Req.Response{status: 404}}, user) do
    # if an FCM token is deleted, it won’t be recreated later, so prune the user now
    case Repo.delete(user) do
      {:ok, _} ->
        :deleted

      {:error, error} ->
        Logger.error(inspect(error))
        :error
    end
  end

  defp handle_fcm_response(result, _user) do
    error =
      case result do
        {:ok, %Req.Response{status: status, body: body}} ->
          {"HTTP #{status} #{Plug.Conn.Status.reason_phrase(status)}", body}

        {:error, error} ->
          error
      end

    Logger.error(inspect(error))
    Sentry.capture_message("FCM delivery failed: #{inspect(error)}")
    :error
  end
end

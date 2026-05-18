defmodule MobileAppBackend.Notifications.Deliverer do
  use Oban.Worker, unique: [period: :infinity], max_attempts: 4
  require Logger
  alias GoogleApi.FCM.V1, as: FCM
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.GCPToken
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

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
    connection = FCM.Connection.new(gcp_token)

    # in Android, a notification with a tag will replace an old notification with the same tag
    tag =
      case type do
        :all_clear -> "#{alert_id}-all-clear"
        _ -> alert_id
      end

    request_body = %FCM.Model.SendMessageRequest{
      message: %FCM.Model.Message{
        notification: %{
          title: title,
          body: body
        },
        data: %{deep_link_path: deep_link_path},
        android: %FCM.Model.AndroidConfig{
          notification: %FCM.Model.AndroidNotification{
            sound: "default",
            tag: tag
          }
        },
        apns: %FCM.Model.ApnsConfig{
          payload: %{aps: %{sound: "default"}}
        },
        fcmOptions: %FCM.Model.FcmOptions{
          analyticsLabel: analytics_label
        },
        token: user.fcm_token
      }
    }

    result =
      FCM.Api.Projects.fcm_projects_messages_send(
        connection,
        "projects/mbta-app-c574d",
        body: request_body
      )
      |> handle_fcm_response(user)

    Logger.info(
      "#{__MODULE__} notification_sent result=#{result} type=#{type} alert_id=#{alert_id}"
    )

    if result == :ok do
      Repo.insert!(%DeliveredNotification{
        user_id: user_id,
        alert_id: alert_id,
        upstream_timestamp: upstream_timestamp,
        type: type
      })
    end

    :ok
  end

  defp handle_fcm_response({:ok, _response}, user) do
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

  defp handle_fcm_response({:error, %Tesla.Env{status: 404}}, user) do
    # if an FCM token is deleted, it won’t be recreated later, so prune the user now
    case Repo.delete(user) do
      {:ok, _} ->
        :deleted

      {:error, error} ->
        Logger.error(inspect(error))
        :error
    end
  end

  defp handle_fcm_response({:error, error}, _user) do
    Logger.error(inspect(error))
    Sentry.capture_message("FCM delivery failed: #{inspect(error)}")
    :error
  end
end

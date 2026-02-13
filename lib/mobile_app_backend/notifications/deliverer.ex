defmodule MobileAppBackend.Notifications.Deliverer do
  use Oban.Worker, unique: [period: :infinity]
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
          "summary" => summary,
          "subscriptions" => subscriptions,
          "upstream_timestamp" => upstream_timestamp,
          "type" => type
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

    request_body = %FCM.Model.SendMessageRequest{
      message: %FCM.Model.Message{
        data: %{
          summary: Jason.encode!(summary),
          alert_id: alert_id,
          subscriptions: Jason.encode!(subscriptions),
          notification_type: type,
          sent_at: to_string(DateTime.utc_now())
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
      |> case do
        {:ok, _} ->
          user
          |> Ecto.Changeset.change(fcm_last_verified: DateTime.utc_now(:second))
          |> Repo.update!()

          :ok

        {:error, %Tesla.Env{status: 404}} ->
          # if an FCM token is deleted, it won’t be recreated later, so prune the user now
          Repo.delete!(user)
          :deleted

        {:error, error} ->
          Logger.error(inspect(error))
          Sentry.capture_message("FCM delivery failed: #{inspect(error)}")
          :error
      end

    if result != :deleted do
      Repo.insert!(%DeliveredNotification{
        user_id: user_id,
        alert_id: alert_id,
        upstream_timestamp: upstream_timestamp,
        type: type
      })
    end

    :ok
  end
end

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
          "subscriptions" => subscriptions,
          "upstream_timestamp" => upstream_timestamp
        }
      }) do
    {:ok, upstream_timestamp, _} = DateTime.from_iso8601(upstream_timestamp)
    Logger.info("#{__MODULE__} sending alert #{alert_id} to user #{user_id}")

    user = Repo.get!(User, user_id)

    gcp_token = GCPToken.get_token()
    connection = FCM.Connection.new(gcp_token)

    request_body = %FCM.Model.SendMessageRequest{
      message: %FCM.Model.Message{
        data: %{alertId: alert_id, subscriptions: Jason.encode!(subscriptions)},
        token: user.fcm_token
      }
    }

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

      {:error, error} ->
        Logger.error(inspect(error))
        Sentry.capture_message("FCM delivery failed: #{inspect(error)}")
        :error
    end

    Repo.insert!(%DeliveredNotification{
      user_id: user_id,
      alert_id: alert_id,
      upstream_timestamp: upstream_timestamp
    })

    :ok
  end
end

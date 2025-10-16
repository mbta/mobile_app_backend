defmodule MobileAppBackend.Notifications.Deliverer do
  use Oban.Worker, unique: [period: :infinity]
  require Logger
  alias GoogleApi.FCM.V1, as: FCM
  alias MBTAV3API.Alert
  alias MBTAV3API.Store.Alerts
  alias MobileAppBackend.Notifications.DeliveredNotification
  alias MobileAppBackend.Notifications.GCPToken
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

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

    user = Repo.get!(User, user_id)
    [alert] = Alerts.fetch(id: alert_id)

    gcp_token = GCPToken.get_token()
    connection = FCM.Connection.new(gcp_token)

    vehicle_types =
      MapSet.new(alert.informed_entity, fn %Alert.InformedEntity{route_type: route_type} ->
        case route_type do
          route_type when route_type in [:light_rail, :heavy_rail, :commuter_rail] -> :train
          :bus -> :bus
          :ferry -> :ferry
        end
      end)
      |> Enum.join(" / ")

    request_body = %FCM.Model.SendMessageRequest{
      message: %FCM.Model.Message{
        notification: %FCM.Model.Notification{
          title: "Alert #{alert_id}",
          body: "Hello we are your #{vehicle_types}"
        },
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

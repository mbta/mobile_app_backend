defmodule MobileAppBackendWeb.NotificationSubscriptionsController do
  use MobileAppBackendWeb, :controller

  import Ecto.Query

  alias MobileAppBackend.Notifications.WritePayload
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  def write(conn, params) do
    status =
      case WritePayload.parse(params) do
        {:ok, payload} ->
          now = Map.get_lazy(conn.private, :mobile_app_backend_now, &DateTime.utc_now/0)

          case perform_write(payload, now) do
            {:ok, _} ->
              :ok

            {:error, error} ->
              Sentry.capture_message(
                "NotificationSubscriptionsController.write/2 failure: #{inspect(error)}"
              )

              :internal_server_error
          end

        :error ->
          :bad_request
      end

    conn |> put_status(status) |> json(nil)
  end

  @spec perform_write(WritePayload.t(), DateTime.t()) :: {:ok, :ok} | {:error, term()}
  defp perform_write(payload, now) do
    fcm_token = payload.fcm_token

    Repo.transact(fn ->
      user =
        Repo.one(
          from u in User,
            where: u.fcm_token == ^fcm_token,
            preload: [notification_subscriptions: :windows]
        )
        |> case do
          nil -> %User{fcm_token: fcm_token}
          user -> user
        end

      changeset =
        user |> Ecto.Changeset.change(fcm_last_verified: now) |> WritePayload.changeset(payload)

      case Repo.insert_or_update(changeset) do
        {:ok, _} -> {:ok, :ok}
        {:error, error} -> {:error, error}
      end
    end)
  end
end

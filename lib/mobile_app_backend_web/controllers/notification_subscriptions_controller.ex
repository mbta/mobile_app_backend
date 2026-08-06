defmodule MobileAppBackendWeb.NotificationSubscriptionsController do
  use MobileAppBackendWeb, :controller

  import Ecto.Query

  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.WritePayload
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User
  alias Util.FCMTarget

  def set_include_accessibility(conn, params) do
    status =
      with {:ok, fcm_target} <- FCMTarget.parse(params),
           {:ok, include_accessibility} <- Map.fetch(params, "include_accessibility") do
        locale = params["locale"]

        now = Map.get_lazy(conn.private, :mobile_app_backend_now, &DateTime.utc_now/0)

        user_where = FCMTarget.user_where(fcm_target)

        Repo.update_all(
          from(u in User,
            where: ^user_where,
            update: [set: [fcm_last_verified: ^now, locale: coalesce(^locale, u.locale)]]
          ),
          []
        )

        Repo.update_all(
          from(ns in Subscription,
            join: u in subquery(from u in User, where: ^user_where),
            on: ns.user_id == u.id
          ),
          set: [include_accessibility: include_accessibility]
        )

        :ok
      else
        :error -> :bad_request
      end

    conn |> put_status(status) |> json(nil)
  end

  def write(conn, params) do
    status =
      case WritePayload.parse(params) do
        {:ok, payload} ->
          now =
            Map.get_lazy(conn.private, :mobile_app_backend_now, fn ->
              DateTime.utc_now(:second)
            end)

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
    user_where = FCMTarget.user_where(payload.fcm_target)

    Repo.transact(fn ->
      user =
        Repo.one(
          from u in User,
            where: ^user_where,
            preload: [notification_subscriptions: :windows]
        )
        |> case do
          nil -> FCMTarget.new_user(payload.fcm_target)
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

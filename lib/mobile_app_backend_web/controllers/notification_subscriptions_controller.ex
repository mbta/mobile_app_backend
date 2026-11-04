defmodule MobileAppBackendWeb.NotificationSubscriptionsController do
  use MobileAppBackendWeb, :controller

  import Ecto.Query

  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.WritePayload
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  def set_include_accessibility(conn, params) do
    status =
      with {:ok, fcm_token} <- Map.fetch(params, "fcm_token"),
           {:ok, include_accessibility} <- Map.fetch(params, "include_accessibility") do
        locale = params["locale"]

        now = Map.get_lazy(conn.private, :mobile_app_backend_now, &DateTime.utc_now/0)

        Repo.update_all(
          from(u in User,
            where: u.fcm_token == ^fcm_token,
            update: [set: [fcm_last_verified: ^now, locale: coalesce(^locale, u.locale)]]
          ),
          []
        )

        Repo.update_all(
          from(ns in Subscription, join: u in assoc(ns, :user), where: u.fcm_token == ^fcm_token),
          set: [include_accessibility: include_accessibility]
        )

        :ok
      else
        :error -> :bad_request
      end

    conn |> put_status(status) |> json(nil)
  end

  def write(conn, params) do
    user_agent =
      conn
      |> get_req_header("user-agent")
      |> List.first()
      |> to_string()

    [app_version, platform] =
      Regex.run(~r{/(\d+(?:\.\d+)*) \(([^)]+)\)}, user_agent, capture: :all_but_first) ||
        [nil, nil]

    status =
      case WritePayload.parse(
             Map.merge(params, %{"app_version" => app_version, "platform" => platform})
           ) do
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

  # A write for a token that was last verified this recently is probably a duplicate request
  @duplicate_window_seconds 5

  @spec perform_write(WritePayload.t(), DateTime.t()) :: {:ok, :ok} | {:error, term()}
  defp perform_write(payload, now) do
    fcm_token = payload.fcm_token

    Repo.transact(fn ->
      # Serialize all writes for the same token so that concurrent requests can’t both decide
      # to insert the same user or subscription. The lock is released when the transaction ends.
      Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", [fcm_token])

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
        user
        |> Ecto.Changeset.change(fcm_last_verified: now)
        |> Ecto.Changeset.unique_constraint(:fcm_token, name: :fcm_unique_index)
        |> WritePayload.changeset(payload)

      report_conflicting_duplicate(user, changeset, now)

      case Repo.insert_or_update(changeset) do
        {:ok, _} -> {:ok, :ok}
        {:error, error} -> {:error, error}
      end
    end)
  end

  # If the same user was just written and this request still changes something, then either
  # the user really did change things quickly or two requests with differing contents raced.
  @spec report_conflicting_duplicate(User.t(), Ecto.Changeset.t(User.t()), DateTime.t()) :: :ok
  defp report_conflicting_duplicate(%User{fcm_last_verified: nil}, _changeset, _now), do: :ok

  defp report_conflicting_duplicate(%User{} = user, changeset, now) do
    if DateTime.diff(now, user.fcm_last_verified) in 0..@duplicate_window_seconds//1 do
      case change_summary(changeset) do
        nil ->
          :ok

        summary ->
          Sentry.capture_message(
            "NotificationSubscriptionsController.write/2 near-duplicate request with differing content",
            level: :warning,
            extra: %{user_id: user.id, changes: summary}
          )

          :ok
      end
    else
      :ok
    end
  end

  # Describes which fields changed, without including the FCM token
  @spec change_summary(Ecto.Changeset.t(User.t())) :: map() | nil
  defp change_summary(%Ecto.Changeset{changes: changes}) do
    {subscription_changesets, user_changes} =
      changes |> Map.delete(:fcm_last_verified) |> Map.pop(:notification_subscriptions, [])

    subscriptions =
      subscription_changesets
      |> Enum.reject(&(&1.action == :update and &1.changes == %{}))
      |> Enum.map(fn subscription ->
        %{
          action: subscription.action,
          key: WritePayload.Subscription.key(subscription),
          fields: Map.keys(subscription.changes)
        }
      end)

    user_fields = Map.keys(user_changes)

    if user_fields == [] and subscriptions == [] do
      nil
    else
      %{user_fields: user_fields, subscriptions: subscriptions}
    end
  end
end

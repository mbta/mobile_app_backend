defmodule MobileAppBackendWeb.NotificationSubscriptionsControllerConcurrencyTest do
  # Real commits are needed for the writes to actually contend, so this can’t use the sandbox
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  alias Ecto.Adapters.SQL.Sandbox
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  @endpoint MobileAppBackendWeb.Endpoint

  setup do
    Sandbox.mode(Repo, :auto)

    on_exit(fn ->
      Repo.delete_all(Window)
      Repo.delete_all(Subscription)
      Repo.delete_all(User)
      Sandbox.mode(Repo, :manual)
    end)
  end

  @tag :capture_log
  test "concurrent writes for a new token create a single user" do
    payload = %{
      fcm_token: "concurrent_token",
      subscriptions: [
        %{
          route_id: "Red",
          stop_id: "place-sstat",
          direction_id: 0,
          include_accessibility: true,
          windows: [%{start_time: "08:00", end_time: "09:00", days_of_week: [1, 2, 3]}]
        }
      ]
    }

    statuses =
      1..8
      |> Task.async_stream(
        fn _ ->
          build_conn()
          |> post("/api/notifications/subscriptions/write", payload)
          |> Map.fetch!(:status)
        end,
        max_concurrency: 8,
        ordered: false,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, status} -> status end)

    assert Enum.all?(statuses, &(&1 == 200))
    assert [%User{fcm_token: "concurrent_token"}] = Repo.all(User)
    assert Repo.aggregate(Subscription, :count) == 1
    assert Repo.aggregate(Window, :count) == 1
  end
end

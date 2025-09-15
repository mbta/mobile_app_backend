defmodule MobileAppBackendWeb.NotificationSubscriptionsControllerTest do
  use MobileAppBackendWeb.ConnCase

  import Ecto.Query
  import MobileAppBackend.NotificationsFactory

  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  setup %{conn: conn} do
    now = DateTime.utc_now(:second)
    conn = put_private(conn, :mobile_app_backend_now, now)
    %{conn: conn, now: now}
  end

  describe "/accessibility" do
    test "sets values of only the correct user", %{conn: conn} do
      [user1, user2] =
        insert_pair(:user,
          notification_subscriptions: fn ->
            build_pair(:notification_subscription, include_accessibility: true)
          end
        )

      assert Enum.all?(user1.notification_subscriptions, & &1.include_accessibility)
      assert Enum.all?(user2.notification_subscriptions, & &1.include_accessibility)

      conn =
        post(conn, "/api/notifications/subscriptions/accessibility", %{
          fcm_token: user1.fcm_token,
          include_accessibility: false
        })

      assert json_response(conn, :ok) == nil

      user1 = Repo.preload(user1, :notification_subscriptions, force: true)
      user2 = Repo.preload(user2, :notification_subscriptions, force: true)

      assert Enum.all?(user1.notification_subscriptions, &(not &1.include_accessibility))
      assert Enum.all?(user2.notification_subscriptions, & &1.include_accessibility)
    end

    test "correctly ignores unknown FCM token", %{conn: conn} do
      conn =
        post(conn, "/api/notifications/subscriptions/accessibility", %{
          fcm_token: "fake_token",
          include_accessibility: true
        })

      assert json_response(conn, :ok) == nil
    end

    test "refreshes FCM verification", %{conn: conn, now: now} do
      user = insert(:user)

      conn =
        post(conn, "/api/notifications/subscriptions/accessibility", %{
          fcm_token: user.fcm_token,
          include_accessibility: true
        })

      assert json_response(conn, :ok) == nil
      assert %User{fcm_last_verified: ^now} = Repo.reload(user)
    end

    test "sends 400 on bad request", %{conn: conn} do
      conn =
        post(conn, "/api/notifications/subscriptions/accessibility", %{is_reasonable: false})

      assert json_response(conn, :bad_request) == nil
    end
  end

  describe "/write" do
    test "creates new user with subscription", %{conn: conn, now: now} do
      conn =
        post(conn, "/api/notifications/subscriptions/write", %{
          fcm_token: "fake_token",
          subscriptions: [
            %{
              route_id: "Red",
              stop_id: "place-sstat",
              direction_id: 0,
              include_accessibility: true,
              windows: [
                %{start_time: "08:00", end_time: "09:00", days_of_week: [1, 2, 3, 4, 5]},
                %{start_time: "10:00", end_time: "17:00", days_of_week: [0, 7]}
              ]
            }
          ]
        })

      assert json_response(conn, :ok) == nil

      assert [%User{id: user_id, fcm_token: "fake_token", fcm_last_verified: ^now}] =
               Repo.all(User)

      assert [
               %Subscription{
                 id: subscription_id,
                 user_id: ^user_id,
                 route_id: "Red",
                 stop_id: "place-sstat",
                 direction_id: 0,
                 include_accessibility: true
               }
             ] = Repo.all(Subscription)

      assert [
               %Window{
                 subscription_id: ^subscription_id,
                 start_time: ~T[08:00:00],
                 end_time: ~T[09:00:00],
                 days_of_week: [1, 2, 3, 4, 5]
               },
               %Window{
                 subscription_id: ^subscription_id,
                 start_time: ~T[10:00:00],
                 end_time: ~T[17:00:00],
                 days_of_week: [0, 7]
               }
             ] = Repo.all(from(w in Window, order_by: w.start_time))
    end

    test "removes subscription", %{conn: conn, now: now} do
      user = insert(:user, notification_subscriptions: [build(:notification_subscription)])

      assert Repo.aggregate(Subscription, :count) == 1
      assert Repo.aggregate(Window, :count) > 0

      conn =
        post(conn, "/api/notifications/subscriptions/write", %{
          fcm_token: user.fcm_token,
          subscriptions: []
        })

      assert json_response(conn, :ok) == nil
      assert [%User{fcm_last_verified: ^now}] = Repo.all(User)
      assert Repo.aggregate(Subscription, :count) == 0
      assert Repo.aggregate(Window, :count) == 0
    end

    test "modifies subscription including windows", %{conn: conn} do
      user = insert(:user)

      old_subscription =
        insert(:notification_subscription, user: user, windows: build_list(3, :window))

      new_windows =
        old_subscription.windows
        |> Enum.drop(-1)
        |> Enum.map(fn %Window{
                         start_time: start_time,
                         end_time: end_time,
                         days_of_week: days_of_week
                       } ->
          %{
            start_time: start_time |> Time.add(15, :second) |> Time.to_iso8601(),
            end_time: end_time |> Time.add(-15, :second) |> Time.to_iso8601(),
            days_of_week:
              case days_of_week do
                [single_day] -> Enum.sort([single_day, Integer.mod(single_day, 7) + 1])
                [_first_day | days] -> days
              end
          }
        end)

      conn =
        post(conn, "/api/notifications/subscriptions/write", %{
          fcm_token: user.fcm_token,
          subscriptions: [
            %{
              route_id: old_subscription.route_id,
              stop_id: old_subscription.stop_id,
              direction_id: old_subscription.direction_id,
              include_accessibility: not old_subscription.include_accessibility,
              windows: new_windows
            }
          ]
        })

      assert json_response(conn, :ok) == nil
      assert [new_subscription] = Repo.all(from(Subscription, preload: :windows))

      assert new_subscription.user_id == old_subscription.user_id
      assert new_subscription.id == old_subscription.id
      assert new_subscription.route_id == old_subscription.route_id
      assert new_subscription.stop_id == old_subscription.stop_id
      assert new_subscription.direction_id == old_subscription.direction_id

      assert new_subscription.include_accessibility == not old_subscription.include_accessibility
      assert length(new_subscription.windows) == length(old_subscription.windows) - 1

      Enum.zip_with(new_subscription.windows, old_subscription.windows, fn new_window,
                                                                           old_window ->
        assert new_window.id == old_window.id
        assert Time.compare(new_window.start_time, old_window.start_time) == :gt
        assert Time.compare(new_window.end_time, old_window.end_time) == :lt
        assert length(new_window.days_of_week) != length(old_window.days_of_week)
      end)
    end

    test "sends 400 on bad request", %{conn: conn} do
      conn =
        post(conn, "/api/notifications/subscriptions/write", %{
          fcm_token: "fake_token",
          subscriptions: [
            %{
              route_id: "Red",
              stop_id: "place-sstat",
              direction_id: 0,
              include_accessibility: true,
              windows: [
                %{start_time: "not-a-time", end_time: "09:00", days_of_week: [1, 2, 3, 4, 5]}
              ]
            }
          ]
        })

      assert json_response(conn, :bad_request) == nil
    end
  end
end

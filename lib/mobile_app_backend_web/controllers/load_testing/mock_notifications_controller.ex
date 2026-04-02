defmodule MobileAppBackendWeb.LoadTesting.MockNotificationsController do
  use MobileAppBackendWeb, :controller
  import Ecto.Query

  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Notifications.Window
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  @mock_user_token_prefix "mock_user_"

  def add_users(conn, %{"count" => count}) do
    count = String.to_integer(count)

    count_before = Repo.aggregate(User, :count)

    Repo.all(User)

    Enum.each(1..count, fn _ -> create_user_with_subscriptions() end)

    count_after = Repo.aggregate(User, :count)

    mock_subscriptions_by_route =
      Repo.all(
        from u in User,
          where: like(u.fcm_token, "mock_user_%"),
          preload: [:notification_subscriptions]
      )
      |> Enum.flat_map(& &1.notification_subscriptions)
      |> Enum.frequencies_by(& &1.route_id)

    json(conn, %{
      count_before: count_before,
      count_after: count_after,
      subscriptions_by_route: mock_subscriptions_by_route
    })
  end

  def delete_users(conn, _params) do
    count_before = Repo.aggregate(User, :count)

    Repo.delete_all(from u in User, where: like(u.fcm_token, "mock_user_%"))

    count_after = Repo.aggregate(User, :count)

    json(conn, %{
      count_before: count_before,
      count_after: count_after
    })
  end

  defp create_user_with_subscriptions do
    user = %User{
      fcm_token: "#{@mock_user_token_prefix}_#{Uniq.UUID.uuid7()}",
      fcm_last_verified: DateTime.utc_now(:second),
      notification_subscriptions: [random_subscription()]
    }

    Repo.insert(user)
  end

  defp random_subscription do
    global_data = GlobalDataCache.get_data()

    probability_red_max = 0.18
    probability_green_max = 0.35
    probability_orange_max = 0.46
    probability_cr_prov_max = 0.51
    probability_blue_max = 0.55

    remaining_routes =
      global_data.routes
      |> Map.values()
      |> Enum.filter(
        &(&1.type in [:bus, :ferry, :commuter_rail] && !String.starts_with?(&1.id, "Shuttle-"))
      )

    route_id =
      case :rand.uniform() do
        p when p < probability_red_max ->
          "Red"

        p when p < probability_green_max ->
          Enum.random(["Green-B", "Green-C", "Green-D", "Green-E"])

        p when p < probability_orange_max ->
          "Orange"

        p when p < probability_cr_prov_max ->
          "CR-Providence"

        p when p < probability_blue_max ->
          "Blue"

        _ ->
          Enum.random(remaining_routes).id
      end

    route_pattern =
      global_data.route_patterns
      |> Map.values()
      |> Enum.filter(&(&1.route_id == route_id))
      |> MBTAV3API.RoutePattern.canonical_or_most_typical_per_route()
      |> List.first()

    stop_id =
      global_data.trips
      |> Map.fetch!(route_pattern.representative_trip_id)
      |> Map.get(:stop_ids)
      |> List.first()

    %Subscription{
      route_id: route_id,
      stop_id: stop_id,
      direction_id: route_pattern.direction_id,
      include_accessibility: true,
      windows: [
        %Window{
          start_time: ~T[00:00:00],
          end_time: ~T[23:50:00],
          days_of_week: [0, 1, 2, 3, 4, 5, 6]
        },
        %{
          start_time: ~T[23:50:01],
          end_time: ~T[23:59:59],
          days_of_week: [0, 1, 2, 3, 4, 5, 6]
        }
      ]
    }
  end
end

defmodule MobileAppBackendWeb.LoadTesting.MockNotificationControllerTest do
  use MobileAppBackendWeb.ConnCase

  import Mox
  import Test.Support.Helpers

  alias MobileAppBackend.Factory
  alias MobileAppBackend.NotificationsFactory
  alias MobileAppBackend.Repo
  alias MobileAppBackend.User

  describe "add & delete users" do
    test "adds the expected number of mock users and deletes all mocked users", %{conn: conn} do
      NotificationsFactory.insert(:user)

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.GlobalDataCache.Module,
        GlobalDataCacheMock
      )

      GlobalDataCacheMock
      |> expect(:default_key, 105, fn -> :default_key end)
      |> expect(:get_data, 105, fn _ -> mock_global() end)

      conn =
        get(conn, "/dev/load_testing/notifications/add_users", %{
          count: 100
        })

      assert json_response(conn, :ok) == %{"count_before" => 1, "count_after" => 101}

      assert 101 == Repo.aggregate(User, :count)

      conn =
        get(conn, "/dev/load_testing/notifications/add_users", %{
          count: 5
        })

      assert 106 == Repo.aggregate(User, :count)

      get(conn, "/dev/load_testing/notifications/delete_users")

      assert 1 == Repo.aggregate(User, :count)
    end
  end

  defp mock_global do
    %{
      lines: %{},
      pattern_ids_by_stop: %{},
      routes: %{
        "Red" => Factory.build(:route, %{id: "Red"}),
        "Orange" => Factory.build(:route, %{id: "Orange"}),
        "Green-B" => Factory.build(:route, %{id: "Green-B"}),
        "Green-C" => Factory.build(:route, %{id: "Green-C"}),
        "Green-D" => Factory.build(:route, %{id: "Green-D"}),
        "Green-E" => Factory.build(:route, %{id: "Green-E"}),
        "Blue" => Factory.build(:route, %{id: "Blue"}),
        "CR-Providence" => Factory.build(:route, %{id: "CR-Providence"}),
        "1" => Factory.build(:route, %{id: "1", type: :bus})
      },
      route_patterns: %{
        "r1" =>
          Factory.build(:route_pattern, %{
            route_id: "Red",
            representative_trip_id: "tr1",
            typicality: :typical
          }),
        "o1" =>
          Factory.build(:route_pattern, %{
            route_id: "Orange",
            representative_trip_id: "o1",
            typicality: :typical
          }),
        "gb1" =>
          Factory.build(:route_pattern, %{
            route_id: "Green-B",
            representative_trip_id: "gb1",
            typicality: :typical
          }),
        "gc1" =>
          Factory.build(:route_pattern, %{
            route_id: "Green-C",
            representative_trip_id: "gc1",
            typicality: :typical
          }),
        "gd1" =>
          Factory.build(:route_pattern, %{
            route_id: "Green-D",
            representative_trip_id: "gd1",
            typicality: :typical
          }),
        "ge1" =>
          Factory.build(:route_pattern, %{
            route_id: "Green-E",
            representative_trip_id: "ge1",
            typicality: :typical
          }),
        "b1" =>
          Factory.build(:route_pattern, %{
            route_id: "Blue",
            representative_trip_id: "b1",
            typicality: :typical
          }),
        "crp1" =>
          Factory.build(:route_pattern, %{
            route_id: "CR-Providence",
            representative_trip_id: "crp1",
            typicality: :typical
          }),
        "t1" =>
          Factory.build(:route_pattern, %{
            route_id: "1",
            representative_trip_id: "t1",
            typicality: :typical
          })
      },
      stops: %{},
      trips: %{
        "tr1" => Factory.build(:trip, %{stop_ids: ["s1"]}),
        "o1" => Factory.build(:trip, %{stop_ids: ["s2"]}),
        "gb1" => Factory.build(:trip, %{stop_ids: ["s3"]}),
        "gc1" => Factory.build(:trip, %{stop_ids: ["s4"]}),
        "gd1" => Factory.build(:trip, %{stop_ids: ["s5"]}),
        "ge1" => Factory.build(:trip, %{stop_ids: ["s6"]}),
        "b1" => Factory.build(:trip, %{stop_ids: ["s7"]}),
        "crp1" => Factory.build(:trip, %{stop_ids: ["s8"]}),
        "t1" => Factory.build(:trip, %{stop_ids: ["s9"]})
      }
    }
  end
end

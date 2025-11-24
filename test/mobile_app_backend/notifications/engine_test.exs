defmodule MobileAppBackend.Notifications.EngineTest do
  use ExUnit.Case, async: false
  use HttpStub.Case
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  alias MBTAV3API.Alert
  alias MobileAppBackend.Notifications.Engine
  alias MobileAppBackend.NotificationsFactory

  setup :verify_on_exit!

  test "matches Green Line subscription to individual routes" do
    alert = build(:alert, informed_entity: [%Alert.InformedEntity{route: "Green-D"}])
    subscription = NotificationsFactory.build(:notification_subscription, route_id: "line-Green")
    assert Engine.matches?(alert, subscription)
  end

  test "matches parent subscription to child stop" do
    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    GlobalDataCacheMock
    |> expect(:default_key, 2, fn -> :default_key end)
    |> expect(:get_data, 2, fn _ ->
      %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: %{},
        route_patterns: %{},
        stops: %{
          "70158" => %MBTAV3API.Stop{
            parent_station_id: "place-boyls"
          }
        },
        trips: %{}
      }
    end)

    alert = build(:alert, informed_entity: [%Alert.InformedEntity{stop: "70158"}])
    subscription = NotificationsFactory.build(:notification_subscription, stop_id: "place-boyls")
    assert Engine.matches?(alert, subscription)
  end

  test "includes downstream alerts" do
    alert =
      build(:alert,
        effect: :station_closure,
        informed_entity: [
          %Alert.InformedEntity{
            activities: [:board, :exit],
            direction_id: 0,
            route: "Orange",
            stop: "70004"
          },
          %Alert.InformedEntity{
            activities: [:board, :exit],
            direction_id: 1,
            route: "Orange",
            stop: "70005"
          }
        ]
      )

    subscription =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Orange",
        stop_id: "place-north",
        direction_id: 0
      )

    assert Engine.matches?(alert, subscription)
  end
end

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
    alert =
      build(:alert,
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], route: "Green-D"}]
      )

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
    |> expect(:default_key, fn -> :default_key end)
    |> expect(:get_data, fn _ ->
      %{
        lines: %{},
        pattern_ids_by_stop: %{},
        routes: %{},
        route_patterns: %{},
        stops: %{
          "place-boyls" => %MBTAV3API.Stop{
            child_stop_ids: ["70158"]
          }
        },
        trips: %{}
      }
    end)

    alert =
      build(:alert,
        effect: :suspension,
        informed_entity: [%Alert.InformedEntity{activities: [:board], stop: "70158"}]
      )

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

  test "includes elevator closures if requested" do
    alert =
      build(:alert,
        effect: :elevator_closure,
        informed_entity: [
          %Alert.InformedEntity{
            activities: [:using_wheelchair],
            stop: "place-chncl"
          }
        ]
      )

    subscription_including =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Orange",
        stop_id: "place-chncl",
        direction_id: 0,
        include_accessibility: true
      )

    assert Engine.matches?(alert, subscription_including)

    subscription_excluding =
      NotificationsFactory.build(:notification_subscription,
        route_id: "Orange",
        stop_id: "place-chncl",
        direction_id: 0,
        include_accessibility: false
      )

    refute Engine.matches?(alert, subscription_excluding)
  end
end

defmodule MobileAppBackendWeb.AlertsChannelTest do
  use MobileAppBackendWeb.ChannelCase
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertWithSummaries
  alias MobileAppBackend.Alerts.SummaryEntity

  alias MobileAppBackendWeb.AlertsChannel

  setup do
    reassign_env(:mobile_app_backend, MobileAppBackend.Alerts.PubSub, AlertsPubSubMock)

    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

  setup :verify_on_exit!

  defp to_alert_map(alerts),
    do:
      alerts
      |> Enum.map(fn alert -> {alert.id, alert} end)
      |> Map.new()

  test "joins and subscribes correctly", %{socket: socket} do
    alert1 = %Alert{
      id: "501047",
      active_period: [%Alert.ActivePeriod{start: ~B[2023-05-26 16:46:13]}],
      effect: :station_issue,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{
          activities: [:board],
          route: "Green-D",
          route_type: :light_rail,
          stop: "70511"
        },
        %Alert.InformedEntity{
          activities: [:board],
          route: "88",
          route_type: :bus,
          stop: "place-lech"
        }
      ],
      lifecycle: :ongoing
    }

    alert2 = %Alert{
      id: "559018",
      active_period: [
        %Alert.ActivePeriod{start: ~B[2024-03-14 16:12:00], end: ~B[2024-03-14 18:13:39]}
      ],
      effect: :delay,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{activities: [:board, :exit, :ride], route: "120", route_type: :bus}
      ],
      lifecycle: :new
    }

    data1 = %{alerts: to_alert_map([alert1, alert2])}

    expect(AlertsPubSubMock, :subscribe, 1, fn _ -> data1 end)

    {:ok, ^data1, socket} =
      subscribe_and_join(socket, "alerts")

    data2 = %{alerts: to_alert_map([alert1])}

    AlertsChannel.handle_info({:new_alerts, data2}, socket)

    assert_push("stream_data", ^data2)
  end

  test "joins and subscribes v2 correctly", %{socket: socket} do
    alert1 = %Alert{
      id: "501047",
      active_period: [%Alert.ActivePeriod{start: ~B[2023-05-26 16:46:13]}],
      effect: :station_issue,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{
          activities: [:board],
          route: "Green-D",
          route_type: :light_rail,
          stop: "70511"
        },
        %Alert.InformedEntity{
          activities: [:board],
          route: "88",
          route_type: :bus,
          stop: "place-lech"
        }
      ],
      lifecycle: :ongoing
    }

    alert2 = %Alert{
      id: "559018",
      active_period: [
        %Alert.ActivePeriod{start: ~B[2024-03-14 16:12:00], end: ~B[2024-03-14 18:13:39]}
      ],
      effect: :delay,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{activities: [:board, :exit, :ride], route: "120", route_type: :bus}
      ],
      lifecycle: :new
    }

    data1 = %{alerts: to_alert_map([alert1, alert2])}

    expect(AlertsPubSubMock, :subscribe, 1, fn _ -> data1 end)

    {:ok, ^data1, socket} =
      subscribe_and_join(socket, "alerts:v2")

    data2 = %{alerts: to_alert_map([alert1])}

    AlertsChannel.handle_info({:new_alerts, data2}, socket)

    assert_push("stream_data", ^data2)
  end

  test "joins and subscribes v3 correctly", %{socket: socket} do
    alert1 = %AlertWithSummaries{
      id: "501047",
      active_period: [%Alert.ActivePeriod{start: ~B[2023-05-26 16:46:13]}],
      effect: :station_issue,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{
          activities: [:board],
          route: "Green-D",
          route_type: :light_rail,
          stop: "70511"
        },
        %Alert.InformedEntity{
          activities: [:board],
          route: "88",
          route_type: :bus,
          stop: "place-lech"
        }
      ],
      lifecycle: :ongoing,
      summaries: [%SummaryEntity{summary: "test summary"}]
    }

    alert2 = %AlertWithSummaries{
      id: "559018",
      active_period: [
        %Alert.ActivePeriod{start: ~B[2024-03-14 16:12:00], end: ~B[2024-03-14 18:13:39]}
      ],
      effect: :delay,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{activities: [:board, :exit, :ride], route: "120", route_type: :bus}
      ],
      lifecycle: :new,
      summaries: [%SummaryEntity{summary: "test summary"}]
    }

    alert3 = %AlertWithSummaries{
      id: "559019",
      active_period: [
        %Alert.ActivePeriod{start: ~B[2024-03-14 16:12:00], end: ~B[2024-03-14 18:13:39]}
      ],
      effect: :delay,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{activities: [:board, :exit, :ride], route: "1", route_type: :bus}
      ],
      lifecycle: :new,
      summaries: [%SummaryEntity{summary: "test summary"}]
    }

    data1 = to_alert_map([alert1, alert2, alert3])

    expect(AlertsPubSubMock, :subscribe, 1, fn _ -> %{alerts: data1} end)

    {:ok,
     %AlertsChannel.AlertUpdate{
       remove: [],
       update: ^data1
     }, socket} =
      subscribe_and_join(socket, "alerts:v3")

    data2 = to_alert_map([%{alert1 | description: "different description"}])

    AlertsChannel.handle_info(
      {:new_alerts, %{alerts: Map.merge(data2, %{alert3.id => alert3})}},
      socket
    )

    alert2_id = alert2.id

    assert_push("stream_data", %AlertsChannel.AlertUpdate{
      remove: [^alert2_id],
      update: ^data2
    })
  end

  test "v3 skips updates if there are no changes", %{socket: socket} do
    alert1 = %AlertWithSummaries{
      id: "501047",
      active_period: [%Alert.ActivePeriod{start: ~B[2023-05-26 16:46:13]}],
      effect: :station_issue,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{
          activities: [:board],
          route: "Green-D",
          route_type: :light_rail,
          stop: "70511"
        },
        %Alert.InformedEntity{
          activities: [:board],
          route: "88",
          route_type: :bus,
          stop: "place-lech"
        }
      ],
      lifecycle: :ongoing,
      summaries: [%SummaryEntity{summary: "test summary"}]
    }

    alert2 = %AlertWithSummaries{
      id: "559018",
      active_period: [
        %Alert.ActivePeriod{start: ~B[2024-03-14 16:12:00], end: ~B[2024-03-14 18:13:39]}
      ],
      effect: :delay,
      effect_name: nil,
      informed_entity: [
        %Alert.InformedEntity{activities: [:board, :exit, :ride], route: "120", route_type: :bus}
      ],
      lifecycle: :new,
      summaries: [%SummaryEntity{summary: "test summary"}]
    }

    data1 = to_alert_map([alert1, alert2])

    expect(AlertsPubSubMock, :subscribe, 1, fn _ -> %{alerts: data1} end)

    {:ok,
     %AlertsChannel.AlertUpdate{
       remove: [],
       update: ^data1
     }, socket} =
      subscribe_and_join(socket, "alerts:v3")

    AlertsChannel.handle_info(
      {:new_alerts, %{alerts: data1}},
      socket
    )

    refute_push "stream_data", _
  end
end

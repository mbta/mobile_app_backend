defmodule MobileAppBackendWeb.AlertsChannelTest do
  use MobileAppBackendWeb.ChannelCase
  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import Test.Support.Sigils
  alias MBTAV3API.Alert

  setup do
    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

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

    data1 = to_full_map([alert1, alert2])

    :sys.replace_state(MBTAV3API.Stream.Registry.via_name("alerts"), fn state ->
      put_in(state.state.data, data1)
    end)

    {:ok, ^data1, _socket} =
      subscribe_and_join(socket, MobileAppBackendWeb.AlertsChannel, "alerts")

    data2 = to_full_map([alert1])

    MBTAV3API.Stream.PubSub.broadcast!("alerts", {:stream_data, data2})

    assert_push("stream_data", ^data2)
  end
end

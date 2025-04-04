defmodule MobileAppBackendWeb.PredictionsForStopsV2ChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  alias MobileAppBackendWeb.PredictionsForStopsV2Channel

  setup do
    reassign_env(:mobile_app_backend, :base_url, "https://api.example.net")
    reassign_env(:mobile_app_backend, :api_key, "abcdef")
    reassign_env(:mobile_app_backend, MobileAppBackend.Predictions.PubSub, PredictionsPubSubMock)

    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

  test "joins and leaves ok", %{socket: socket} do
    prediction_1 =
      build(:prediction, id: "p_1", trip_id: "trip_1", stop_id: "12345", vehicle_id: "v_1")

    prediction_2 =
      build(:prediction, id: "p_2", trip_id: "trip_2", stop_id: "67890", vehicle_id: "v_2")

    trip_1 = build(:trip, id: "trip_1")
    trip_2 = build(:trip, id: "trip_2")

    vehicle_1 = build(:vehicle, id: "v_1")
    vehicle_2 = build(:vehicle, id: "v_2")

    response = %{
      predictions_by_stop: %{
        "12345" => %{"p_1" => prediction_1, "p_2" => prediction_2}
      },
      trips: %{"trip_1" => trip_1, "trip_2" => trip_2},
      vehicles: %{"v_1" => vehicle_1, "v_2" => vehicle_2}
    }

    expect(PredictionsPubSubMock, :subscribe_for_stops, 1, fn _ ->
      response
    end)

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "predictions:stops:v2:12345,67890")

    assert reply == response
  end

  test "empty data if missing stop ids in topic", %{socket: socket} do
    assert {:ok, data, _socket} =
             subscribe_and_join(socket, "predictions:stops:v2:")

    assert data == %{predictions_by_stop: %{}, trips: %{}, vehicles: %{}}
  end

  test "handles new predictions", %{socket: socket} do
    expect(PredictionsPubSubMock, :subscribe_for_stops, fn _ -> %{} end)

    {:ok, _reply, socket} =
      subscribe_and_join(socket, "predictions:stops:v2:12345")

    prediction =
      build(:prediction,
        id: "prediction_1",
        stop_id: "12345",
        trip_id: "trip_1",
        vehicle_id: "v_1"
      )

    trip = build(:trip, id: "trip_1")
    vehicle = build(:vehicle, id: "v_1")

    PredictionsForStopsV2Channel.handle_info(
      {:new_predictions, Map.put(to_full_map([prediction, trip, vehicle]), :stop_id, "12345")},
      socket
    )

    assert_push "stream_data", %{
      stop_id: "12345",
      predictions: %{"prediction_1" => ^prediction},
      trips: %{"trip_1" => ^trip},
      vehicles: %{"v_1" => ^vehicle}
    }
  end
end

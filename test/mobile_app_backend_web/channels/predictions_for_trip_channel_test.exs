defmodule MobileAppBackendWeb.PredictionsForTripChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  alias MobileAppBackendWeb.PredictionsForTripChannel

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

    build(:prediction, id: "p_2", trip_id: "trip_2", stop_id: "67890", vehicle_id: "v_2")

    trip_1 = build(:trip, id: "trip_1")
    build(:trip, id: "trip_2")

    vehicle_1 = build(:vehicle, id: "v_1")
    build(:vehicle, id: "v_2")

    response = %{
      predictions: %{
        "12345" => %{"p_1" => prediction_1}
      },
      trips: %{"trip_1" => trip_1},
      vehicles: %{"v_1" => vehicle_1}
    }

    expect(PredictionsPubSubMock, :subscribe_for_trip, 1, fn _ ->
      response
    end)

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "predictions:trip:trip_1")

    assert reply == response
  end

  test "error if missing trip id in topic", %{socket: socket} do
    assert subscribe_and_join(socket, "predictions:trip:") == {:error, %{code: :no_trip_id}}
  end

  test "handles new predictions", %{socket: socket} do
    expect(PredictionsPubSubMock, :subscribe_for_trip, fn _ -> %{} end)

    {:ok, _reply, socket} =
      subscribe_and_join(socket, "predictions:trip:trip_1")

    prediction =
      build(:prediction,
        id: "prediction_1",
        stop_id: "12345",
        trip_id: "trip_1",
        vehicle_id: "v_1"
      )

    trip = build(:trip, id: "trip_1")
    vehicle = build(:vehicle, id: "v_1")

    PredictionsForTripChannel.handle_info(
      {:new_predictions, Map.put(to_full_map([prediction, trip, vehicle]), :trip_id, "trip_1")},
      socket
    )

    assert_push "stream_data", %{
      trip_id: "trip_1",
      predictions: %{"prediction_1" => ^prediction},
      trips: %{"trip_1" => ^trip},
      vehicles: %{"v_1" => ^vehicle}
    }
  end
end

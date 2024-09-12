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
    prediction_1 = build(:prediction)
    prediction_2 = build(:prediction)

    expect(PredictionsPubSubMock, :subscribe_for_stops, 1, fn _ ->
      %{"12345" => [prediction_1], "67890" => [prediction_2]}
    end)

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "predictions:stops:v2:12345,67890")

    assert reply == %{"12345" => [prediction_1], "67890" => [prediction_2]}
  end

  test "error if missing stop ids in topic", %{socket: socket} do
    {:error, %{code: :no_stop_ids}} =
      subscribe_and_join(socket, "predictions:stops:v2:")
  end

  test "handles new predictions", %{socket: socket} do
    expect(PredictionsPubSubMock, :subscribe_for_stops, fn _ -> %{} end)

    {:ok, _reply, socket} =
      subscribe_and_join(socket, "predictions:stops:v2:12345")

    prediction = build(:prediction, stop_id: "12345")

    PredictionsForStopsV2Channel.handle_info(
      {:new_predictions, %{"12345" => [prediction]}},
      socket
    )

    assert_push "stream_data", %{"12345" => [^prediction]}
  end
end

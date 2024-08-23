defmodule MobileAppBackendWeb.PredictionsForStopsChannelV2Test do
  use MobileAppBackendWeb.ChannelCase

  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  alias MobileAppBackend.StopPredictions
  alias Test.Support.FakeStopPredictions

  setup do
    reassign_env(:mobile_app_backend, :base_url, "https://api.example.net")
    reassign_env(:mobile_app_backend, :api_key, "abcdef")
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

  test "joins and leaves ok", %{socket: socket} do
    route_id = "92"

    RepositoryMock
    |> expect(:stops, fn _, _ -> ok_response([]) end)
    |> expect(:routes, fn _, _ -> ok_response([build(:route, id: route_id)]) end)

    prediction = build(:prediction, stop_id: "12345")

    start_link_supervised!(
      {FakeStopPredictions.PubSub,
       stop_id: "12345",
       data: %{
         by_route: %{
           prediction.route_id => %{
             predictions: %{prediction.id => prediction}
           }
         }
       }}
    )

    start_link_supervised!({FakeStopPredictions.PubSub, stop_id: "67890", data: %{by_route: %{}}})

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "predictions:stops:v2:12345,67890")

    assert reply == to_full_map([prediction])
  end

  test "error if missing stop ids in topic", %{socket: socket} do
    {:error, %{code: :no_stop_ids}} =
      subscribe_and_join(socket, "predictions:stops:v2:")
  end

  test "handles messages", %{socket: socket} do
    route_id = "92"

    RepositoryMock
    |> expect(:stops, fn _, _ -> ok_response([]) end)
    |> expect(:routes, fn _, _ -> ok_response([build(:route, id: route_id)]) end)

    prediction = build(:prediction, stop_id: "12345")
    new_prediction = build(:prediction, stop_id: "12345")

    start_link_supervised!(
      {FakeStopPredictions.PubSub,
       stop_id: "12345",
       data: %{by_route: %{prediction.route_id => %{prediction.id => prediction}}}}
    )

    {:ok, _reply, _socket} =
      subscribe_and_join(socket, "predictions:stops:v2:12345")

    Phoenix.PubSub.broadcast!(
      StopPredictions.PubSub,
      "predictions:stop:instance:12345",
      {:new_predictions, %{"12345" => %{predictions: %{new_prediction.id => new_prediction}}}}
    )

    assert_push "stream_data", data

    assert data == %{"12345" => %{predictions: %{new_prediction.id => new_prediction}}}
  end
end

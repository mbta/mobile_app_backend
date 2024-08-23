defmodule MobileAppBackend.StopPredictions.PubSubTest do
  use ExUnit.Case
  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  alias MobileAppBackend.StopPredictions
  alias Test.Support.FakeStaticInstance
  alias Test.Support.FakeStopPredictions

  setup do
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
  end

  setup do
    reassign_env(:mobile_app_backend, StopPredictions.Store, PredictionsStoreMock)
  end

  describe "subscribe/1" do
    test "returns current state" do
      prediction = build(:prediction, stop_id: "12345", route_id: "66")
      prediction2 = build(:prediction, stop_id: "12345", route_id: "39")

      init_state = %{
        by_route: %{
          "66" => %{predictions: %{prediction.id => prediction}},
          "39" => %{predictions: %{prediction2.id => prediction2}}
        }
      }

      start_link_supervised!({FakeStopPredictions.PubSub, stop_id: "12345", data: init_state})

      assert {:ok, to_full_map([prediction, prediction2])} ==
               StopPredictions.PubSub.subscribe("12345")
    end
  end

  describe "init/1" do
    test "returns current state of route predictions" do
      prediction = build(:prediction, stop_id: "121", route_id: "Red")
      prediction2 = build(:prediction, stop_id: "70085", route_id: "Red")

      RepositoryMock
      |> expect(:stops, fn _, _ ->
        ok_response([build(:stop, id: "place-jfk")], [
          build(:stop, id: "121"),
          build(:stop, id: "70085")
        ])
      end)
      |> expect(:routes, fn [filter: [stop: ["place-jfk", "121", "70085"]]], _ ->
        ok_response([
          build(:route, id: "Red")
        ])
      end)

      start_link_supervised!(
        {FakeStaticInstance,
         topic: "predictions:route:Red", data: to_full_map([prediction, prediction2])}
      )

      assert {:ok,
              %{
                stop_id: "place-jfk",
                all_stop_ids: ["place-jfk", "121", "70085"],
                data: %{by_route: %{"Red" => to_full_map([prediction, prediction2])}},
                last_broadcast_msg: nil
              }} ==
               StopPredictions.PubSub.init(stop_id: "place-jfk")
    end

    test "schedules timed broadcast" do
      RepositoryMock
      |> expect(:stops, fn _, _ ->
        ok_response([build(:stop, id: "place-jfk")], [
          build(:stop, id: "121"),
          build(:stop, id: "70085")
        ])
      end)
      |> expect(:routes, fn [filter: [stop: ["place-jfk", "121", "70085"]]], _ ->
        ok_response([
          build(:route, id: "Red")
        ])
      end)

      start_link_supervised!(
        {FakeStaticInstance, topic: "predictions:route:Red", data: to_full_map([])}
      )

      assert {:ok, _response} =
               StopPredictions.PubSub.init(stop_id: "place-jfk")

      assert_receive :timed_broadcast
    end
  end

  describe "handle_info/2" do
    setup do
      reassign_env(:mobile_app_backend, StopPredictions.Store, PredictionsStoreMock)
    end

    test "when new predictions for a route, updates state" do
      prediction_66_1 = build(:prediction, stop_id: "64000", route_id: "66")
      prediction_66_2 = build(:prediction, stop_id: "64000", route_id: "66")
      prediction_19_1 = build(:prediction, stop_id: "64", route_id: "19")

      initial_state = %{
        stop_id: "place-nubn",
        all_stop_ids: ["64000", "64"],
        route_ids: ["66", "19"],
        last_broadcast_msg: nil
      }

      start_link_supervised!(
        {FakeStopPredictions.PubSub, stop_id: "place-nubn", data: %{by_route: %{}}}
      )

      assert {:noreply,
              %{
                stop_id: "place-nubn",
                all_stop_ids: ["64000", "64"],
                route_ids: ["66", "19"],
                last_broadcast_msg: to_full_map([prediction_66_2, prediction_19_1])
              }} ==
               StopPredictions.PubSub.handle_info(
                 {:stream_data, "predictions:route:66", to_full_map([])},
                 initial_state
               )
    end

    test "when new predictions and no previous broadcast, broadcasts on-demand" do
      prediction_66_1 = build(:prediction, stop_id: "64000", route_id: "66")

      initial_state = %{
        stop_id: "place-nubn",
        all_stop_ids: ["64000"],
        route_ids: ["66"],
        last_broadcast_msg: nil
      }

      start_link_supervised!(
        {FakeStopPredictions.PubSub,
         stop_id: "place-nubn",
         data: initial_state,
         predictions_by_route: %{by_route: %{"66" => to_full_map([prediction_66_1])}}}
      )

      :ok =
        Phoenix.PubSub.subscribe(
          StopPredictions.PubSub,
          StopPredictions.PubSub.topic("place-nubn")
        )

      new_predictions = to_full_map([prediction_66_1])

      assert {:noreply,
              %{
                last_broadcast_msg: last_broadcast_msg
              }} =
               StopPredictions.PubSub.handle_info(
                 {:stream_data, "predictions:route:66", new_predictions},
                 initial_state
               )

      assert last_broadcast_msg == new_predictions

      assert_receive {:new_predictions, new_predictions}
      assert %{"place-nubn" => to_full_map([prediction_66_1])} == new_predictions
    end

    test "when new predictions and previous broadcast already, doesn't send immediately" do
      prediction_66_1 = build(:prediction, stop_id: "64000", route_id: "66")
      prediction_66_2 = build(:prediction, stop_id: "64000", route_id: "66")

      initial_state = %{
        stop_id: "place-nubn",
        all_stop_ids: ["64000"],
        route_ids: ["66"],
        last_broadcast_msg: to_full_map([prediction_66_1])
      }

      start_link_supervised!(
        {FakeStopPredictions.PubSub, stop_id: "place-nubn", data: initial_state}
      )

      :ok =
        Phoenix.PubSub.subscribe(
          StopPredictions.PubSub,
          StopPredictions.PubSub.topic("place-nubn")
        )

      new_predictions = to_full_map([prediction_66_2])

      assert {:noreply,
              %{
                last_broadcast_msg: last_broadcast_msg
              }} =
               StopPredictions.PubSub.handle_info(
                 {:stream_data, "predictions:route:66", new_predictions},
                 initial_state
               )

      assert last_broadcast_msg == initial_state.last_broadcast_msg

      refute_receive {:new_predictions, _new_predictions}, 1000
    end

    test ":timed_broadcast schedules broadcast" do
      StopPredictions.PubSub.handle_info(:timed_broadcast, %{})

      assert_receive :broadcast
    end

    test ":broadcast broadcasts if data has changed" do
      prediction = build(:prediction)

      :ok =
        Phoenix.PubSub.subscribe(
          StopPredictions.PubSub,
          StopPredictions.PubSub.topic(prediction.stop_id)
        )

      StopPredictions.PubSub.handle_info(:broadcast, %{
        stop_id: prediction.stop_id,
        last_broadcast_msg: nil,
        data: %{by_route: %{prediction.route_id => to_full_map([prediction])}}
      })

      assert_receive {:new_predictions, new_predictions}

      assert new_predictions == %{prediction.stop_id => to_full_map([prediction])}
    end

    test ":broadcast skips if data hasn't changed" do
      prediction = build(:prediction)

      :ok =
        Phoenix.PubSub.subscribe(
          StopPredictions.PubSub,
          StopPredictions.PubSub.topic(prediction.stop_id)
        )

      StopPredictions.PubSub.handle_info(:broadcast, %{
        stop_id: prediction.stop_id,
        last_broadcast_msg: to_full_map([prediction]),
        data: %{by_route: %{prediction.route_id => prediction}}
      })

      refute_receive :broadcast
    end
  end

  describe "handle_call/3" do
    test ":get_data returns state" do
      initial_state = %{
        data: %{by_route: %{}},
        all_stop_ids: []
      }

      assert {:reply, %{by_route: %{}}, initial_state} ==
               StopPredictions.PubSub.handle_call(:get_data, "me", initial_state)
    end
  end

  describe "filter_data/2" do
    test "properly divides predictions and associated objects" do
      [trip1, trip2] = build_list(2, :trip)
      [vehicle1, vehicle2] = build_list(2, :vehicle)

      prediction1 =
        build(:prediction, stop_id: "12345", trip_id: trip1.id, vehicle_id: vehicle1.id)

      prediction2 =
        build(:prediction, stop_id: "67890", trip_id: trip2.id, vehicle_id: vehicle2.id)

      assert StopPredictions.PubSub.filter_data(
               to_full_map([prediction1, prediction2, trip1, trip2, vehicle1, vehicle2]),
               [
                 "12345",
                 "somewhere-else"
               ]
             ) == to_full_map([prediction1, trip1, vehicle1])
    end
  end
end

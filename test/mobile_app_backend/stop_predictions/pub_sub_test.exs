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
                data: %{by_route: %{"Red" => to_full_map([prediction, prediction2])}}
              }} ==
               StopPredictions.PubSub.init(stop_id: "place-jfk")
    end
  end

  describe "handle_info/2" do
    test "when new predictions for a route, updates state" do
      prediction_66_1 = build(:prediction, stop_id: "64000", route_id: "66")
      prediction_66_2 = build(:prediction, stop_id: "64000", route_id: "66")
      prediction_19_1 = build(:prediction, stop_id: "64", route_id: "19")

      initial_state = %{
        stop_id: "place-nubn",
        all_stop_ids: ["64000", "64"],
        data: %{
          by_route: %{
            "66" => to_full_map([prediction_66_1]),
            "19" => to_full_map([prediction_19_1])
          }
        }
      }

      start_link_supervised!(
        {FakeStopPredictions.PubSub, stop_id: "place-nubn", data: %{by_route: %{}}}
      )

      :ok =
        Phoenix.PubSub.subscribe(
          StopPredictions.PubSub,
          StopPredictions.PubSub.topic("place-nubn")
        )

      assert {:noreply,
              %{
                stop_id: "place-nubn",
                all_stop_ids: ["64000", "64"],
                data: %{
                  by_route: %{
                    "66" => to_full_map([prediction_66_2]),
                    "19" => to_full_map([prediction_19_1])
                  }
                }
              }} ==
               StopPredictions.PubSub.handle_info(
                 {:stream_data, "predictions:route:66", to_full_map([prediction_66_2])},
                 initial_state
               )

      assert_receive {:new_predictions, new_predictions}

      assert %{"place-nubn" => to_full_map([prediction_66_2, prediction_19_1])} == new_predictions
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

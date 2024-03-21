defmodule MobileAppBackendWeb.PredictionsChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction
  alias MBTAV3API.Stream
  alias MBTAV3API.Trip
  alias MBTAV3API.Vehicle
  alias MobileAppBackendWeb.PredictionsChannel
  alias Test.Support.FakeStaticInstance

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
      {FakeStaticInstance,
       topic: "predictions:route:#{route_id}", data: to_full_map([prediction])}
    )

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "predictions:stops", %{"stop_ids" => ["12345", "67890"]})

    assert reply == to_full_map([prediction])
  end

  describe "message handling" do
    setup %{socket: socket} do
      RepositoryMock
      |> expect(:stops, fn _, _ ->
        ok_response([build(:stop, id: "place-jfk")], [
          build(:stop, id: "121"),
          build(:stop, id: "70085"),
          build(:stop, id: "70086"),
          build(:stop, id: "70096"),
          build(:stop, id: "70096"),
          build(:stop, id: "MM-0023-5")
        ])
      end)
      |> expect(:routes, fn _, _ ->
        ok_response([
          build(:route, id: "Red"),
          build(:route, id: "CR-Greenbush"),
          build(:route, id: "8")
        ])
      end)

      {:ok, reply, _socket} =
        subscribe_and_join(socket, "predictions:stops", %{"stop_ids" => ["place-jfk"]})

      assert reply == to_full_map([])

      Stream.PubSub.broadcast!(
        "predictions:route:Red",
        {:stream_data, "predictions:route:Red",
         to_full_map([
           trip_60392455(),
           trip_60392515(),
           vehicle_r_547a83f7(),
           vehicle_r_547a83f8(),
           prediction_60392455(),
           prediction_60392515()
         ])}
      )

      assert_push "stream_data", initial_data

      {:ok, %{initial_data: initial_data}}
    end

    defp trip_60392455 do
      %Trip{id: "60392455", route_pattern_id: "Red-1-1", shape_id: "931_0010"}
    end

    defp trip_60392515 do
      %Trip{id: "60392515", route_pattern_id: "Red-1-0", shape_id: "931_0009"}
    end

    defp vehicle_r_547a83f7 do
      %Vehicle{
        id: "R-547A83F7",
        current_status: :in_transit_to,
        stop_id: "70072",
        trip_id: trip_60392455().id
      }
    end

    defp vehicle_r_547a83f8 do
      %Vehicle{
        id: "R-547A83F8",
        current_status: :stopped_at,
        stop_id: "70085",
        trip_id: trip_60392515().id
      }
    end

    defp prediction_60392455 do
      %Prediction{
        id: "prediction-60392455-70086-90",
        arrival_time: ~B[2024-01-30 15:44:09],
        departure_time: ~B[2024-01-30 15:45:10],
        direction_id: 1,
        revenue: true,
        schedule_relationship: :scheduled,
        stop_sequence: 90,
        route_id: "Red",
        stop_id: "70086",
        trip_id: trip_60392455().id,
        vehicle_id: vehicle_r_547a83f7().id
      }
    end

    defp prediction_60392515 do
      %Prediction{
        id: "prediction-60392515-70085-130",
        arrival_time: ~B[2024-01-30 15:46:26],
        departure_time: ~B[2024-01-30 15:47:48],
        direction_id: 0,
        revenue: true,
        schedule_relationship: :scheduled,
        stop_sequence: 130,
        route_id: "Red",
        stop_id: "70085",
        trip_id: trip_60392515().id,
        vehicle_id: vehicle_r_547a83f8().id
      }
    end

    test "correctly handles reset", %{initial_data: data} do
      assert data ==
               JsonApi.Object.to_full_map([
                 trip_60392455(),
                 trip_60392515(),
                 vehicle_r_547a83f7(),
                 vehicle_r_547a83f8(),
                 prediction_60392455(),
                 prediction_60392515()
               ])
    end

    test "integrates new data" do
      bonus_trip = build(:trip)
      bonus_vehicle = build(:vehicle)

      bonus_prediction =
        build(:prediction, stop_id: "121", trip_id: bonus_trip.id, vehicle_id: bonus_vehicle.id)

      Stream.PubSub.broadcast!(
        "predictions:route:8",
        {:stream_data, "predictions:route:8",
         to_full_map([bonus_trip, bonus_vehicle, bonus_prediction])}
      )

      assert_push "stream_data", data

      assert data ==
               JsonApi.Object.to_full_map([
                 trip_60392455(),
                 trip_60392515(),
                 bonus_trip,
                 vehicle_r_547a83f7(),
                 vehicle_r_547a83f8(),
                 bonus_vehicle,
                 prediction_60392455(),
                 prediction_60392515(),
                 bonus_prediction
               ])
    end

    test "replaces old data" do
      Stream.PubSub.broadcast!(
        "predictions:route:Red",
        {:stream_data, "predictions:route:Red",
         to_full_map([trip_60392455(), vehicle_r_547a83f7(), prediction_60392455()])}
      )

      assert_push "stream_data", data

      assert data ==
               JsonApi.Object.to_full_map([
                 trip_60392455(),
                 vehicle_r_547a83f7(),
                 prediction_60392455()
               ])
    end

    test "ignores irrelevant data" do
      fake_trip = build(:trip)
      fake_vehicle = build(:vehicle)

      fake_prediction = %MBTAV3API.Prediction{
        prediction_60392515()
        | stop_id: "somewhere-else",
          trip_id: fake_trip.id,
          vehicle_id: fake_vehicle.id
      }

      Stream.PubSub.broadcast!(
        "predictions:route:Red",
        {:stream_data, "predictions:route:Red",
         to_full_map([
           trip_60392455(),
           vehicle_r_547a83f7(),
           prediction_60392455(),
           fake_trip,
           fake_vehicle,
           fake_prediction
         ])}
      )

      assert_push "stream_data", data

      assert data ==
               JsonApi.Object.to_full_map([
                 trip_60392455(),
                 vehicle_r_547a83f7(),
                 prediction_60392455()
               ])
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

      assert PredictionsChannel.filter_data(
               to_full_map([prediction1, prediction2, trip1, trip2, vehicle1, vehicle2]),
               [
                 "12345",
                 "somewhere-else"
               ]
             ) == to_full_map([prediction1, trip1, vehicle1])
    end
  end
end

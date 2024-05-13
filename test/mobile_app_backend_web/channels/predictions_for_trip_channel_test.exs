defmodule MobileAppBackendWeb.PredictionsForTripChannelTest do
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
  alias MobileAppBackendWeb.PredictionsForTripChannel
  alias Test.Support.FakeStaticInstance

  setup do
    reassign_env(:mobile_app_backend, :base_url, "https://api.example.net")
    reassign_env(:mobile_app_backend, :api_key, "abcdef")
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

  test "joins and leaves ok", %{socket: socket} do
    trip_id = "81"
    route_id = "92"

    RepositoryMock
    |> expect(:trips, fn [filter: [id: ^trip_id]], _ ->
      ok_response([build(:trip, id: trip_id, route_id: route_id)])
    end)

    prediction = build(:prediction, trip_id: trip_id, stop_id: "12345")

    start_link_supervised!(
      {FakeStaticInstance,
       topic: "predictions:route:#{route_id}", data: to_full_map([prediction])}
    )

    {:ok, reply, _socket} =
      subscribe_and_join(socket, "predictions:trip:#{trip_id}")

    assert reply == to_full_map([prediction])
  end

  describe "message handling" do
    setup %{socket: socket} do
      RepositoryMock
      |> expect(:trips, fn _, _ ->
        ok_response([build(:trip, id: "60392455", route_id: "Red")])
      end)

      {:ok, reply, socket} = subscribe_and_join(socket, "predictions:trip:60392455")

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

      socket.assigns.throttler |> :sys.replace_state(&put_in(&1.last_cast, nil))

      {:ok, %{initial_data: initial_data}}
    end

    defp trip_60392455 do
      %Trip{id: "60392455", direction_id: 1, route_pattern_id: "Red-1-1", shape_id: "931_0010"}
    end

    defp trip_60392515 do
      %Trip{id: "60392515", direction_id: 0, route_pattern_id: "Red-1-0", shape_id: "931_0009"}
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
                 vehicle_r_547a83f7(),
                 prediction_60392455()
               ])
    end

    test "replaces old data" do
      updated_prediction = %Prediction{
        prediction_60392455()
        | arrival_time: ~B[2024-05-08 16:18:21]
      }

      Stream.PubSub.broadcast!(
        "predictions:route:Red",
        {:stream_data, "predictions:route:Red",
         to_full_map([trip_60392455(), vehicle_r_547a83f7(), updated_prediction])}
      )

      assert_push "stream_data", data

      assert data ==
               JsonApi.Object.to_full_map([
                 trip_60392455(),
                 vehicle_r_547a83f7(),
                 updated_prediction
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

      refute_push "stream_data", _
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

      assert PredictionsForTripChannel.filter_data(
               to_full_map([prediction1, prediction2, trip1, trip2, vehicle1, vehicle2]),
               trip1.id
             ) == to_full_map([prediction1, trip1, vehicle1])
    end
  end
end

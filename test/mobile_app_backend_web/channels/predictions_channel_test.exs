defmodule MobileAppBackendWeb.PredictionsChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction
  alias MBTAV3API.Trip
  alias Test.Support.SSEStub

  setup do
    reassign_env(:mobile_app_backend, :base_url, "https://api.example.net")
    reassign_env(:mobile_app_backend, :api_key, "abcdef")

    {:ok, socket} = connect(MobileAppBackendWeb.UserSocket, %{})

    %{socket: socket}
  end

  test "joins and leaves ok", %{socket: socket} do
    {:ok, reply, socket} =
      subscribe_and_join(socket, "predictions:stops", %{"stop_ids" => ["12345", "67890"]})

    assert reply == %{}

    instance = socket.assigns[:stream_instance]
    sse_stub = SSEStub.get_from_instance(instance)

    assert [url: url, headers: [{"x-api-key", "abcdef"}]] = SSEStub.get_args(sse_stub)

    assert %URI{scheme: "https", host: "api.example.net", path: "/predictions", query: query} =
             URI.parse(url)

    assert %{
             "fields[prediction]" =>
               "arrival_time,departure_time,direction_id,revenue_status,schedule_relationship,status,stop_sequence",
             "fields[trip]" => "headsign",
             "filter[stop]" => "12345,67890",
             "include" => "trip"
           } = URI.decode_query(query)

    sse_ref = Process.monitor(sse_stub)
    Process.unlink(socket.channel_pid)
    leave_ref = leave(socket)
    assert_reply leave_ref, :ok

    assert_receive {:DOWN, ^sse_ref, :process, ^sse_stub, :shutdown}
  end

  describe "message handling" do
    setup %{socket: socket} do
      {:ok, reply, socket} =
        subscribe_and_join(socket, "predictions:stops", %{"stop_ids" => ["place-jfk"]})

      assert reply == %{}

      instance = socket.assigns[:stream_instance]
      sse_stub = SSEStub.get_from_instance(instance)

      SSEStub.push_events(sse_stub, [
        %ServerSentEventStage.Event{
          event: "reset",
          data: """
          [
            {"attributes":{},"id":"60392455","links":{"self":"/trips/60392455"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
            {"attributes":{},"id":"60392515","links":{"self":"/trips/60392515"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0009","type":"shape"}}},"type":"trip"},
            {"attributes":{"arrival_time":"2024-01-30T15:44:09-05:00","departure_time":"2024-01-30T15:45:10-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392455-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392455","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F7","type":"vehicle"}}},"type":"prediction"},
            {"attributes":{"arrival_time":"2024-01-30T15:46:26-05:00","departure_time":"2024-01-30T15:47:48-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392515-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392515","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F8","type":"vehicle"}}},"type":"prediction"}
          ]
          """
        }
      ])

      assert_push "stream_data", %{predictions: initial_predictions}

      {:ok, %{sse_stub: sse_stub, initial_predictions: initial_predictions}}
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
        trip: %Trip{
          id: "60392455",
          route_pattern: %JsonApi.Reference{type: "route_pattern", id: "Red-1-1"},
          stops: nil
        }
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
        trip: %Trip{
          id: "60392515",
          route_pattern: %JsonApi.Reference{type: "route_pattern", id: "Red-1-0"},
          stops: nil
        }
      }
    end

    test "correctly handles reset", %{initial_predictions: predictions} do
      assert predictions == [prediction_60392455(), prediction_60392515()]
    end

    test "correctly handles add after reset", %{sse_stub: sse_stub} do
      SSEStub.push_events(sse_stub, [
        %ServerSentEventStage.Event{
          event: "add",
          data: """
          {"attributes":{},"id":"60392593","links":{"self":"/trips/60392593"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"933_0016","type":"shape"}}},"type":"trip"}
          """
        },
        %ServerSentEventStage.Event{
          event: "add",
          data: """
          {"attributes":{"arrival_time":"2024-01-30T17:54:04-05:00","departure_time":"2024-01-30T17:55:45-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":100},"id":"prediction-60392593-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"60392593","type":"trip"}},"vehicle":{"data":{"id":"R-547A80A3","type":"vehicle"}}},"type":"prediction"}
          """
        }
      ])

      assert_push "stream_data", %{predictions: predictions}

      assert predictions == [
               prediction_60392455(),
               prediction_60392515(),
               %Prediction{
                 id: "prediction-60392593-70096-100",
                 arrival_time: ~B[2024-01-30 17:54:04],
                 departure_time: ~B[2024-01-30 17:55:45],
                 direction_id: 1,
                 revenue: true,
                 schedule_relationship: :scheduled,
                 stop_sequence: 100,
                 trip: %Trip{
                   id: "60392593",
                   route_pattern: %JsonApi.Reference{type: "route_pattern", id: "Red-3-1"},
                   stops: nil
                 }
               }
             ]
    end

    test "correctly handles update after reset", %{sse_stub: sse_stub} do
      SSEStub.push_events(sse_stub, [
        %ServerSentEventStage.Event{
          event: "update",
          data: """
          {"attributes":{"arrival_time":"2024-01-30T15:44:26-05:00","departure_time":"2024-01-30T15:45:27-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392455-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392455","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F7","type":"vehicle"}}},"type":"prediction"}
          """
        }
      ])

      assert_push "stream_data", %{predictions: predictions}

      assert predictions == [
               %Prediction{
                 prediction_60392455()
                 | arrival_time: ~B[2024-01-30 15:44:26],
                   departure_time: ~B[2024-01-30 15:45:27]
               },
               prediction_60392515()
             ]
    end

    test "correctly handles remove after reset", %{sse_stub: sse_stub} do
      SSEStub.push_events(sse_stub, [
        %ServerSentEventStage.Event{
          event: "remove",
          data: """
          {"id":"prediction-60392515-70085-130","type":"prediction"}
          """
        },
        %ServerSentEventStage.Event{
          event: "remove",
          data: """
          {"id":"60392515","type":"trip"}
          """
        }
      ])

      assert_push "stream_data", %{predictions: predictions}
      assert predictions == [prediction_60392455()]
    end
  end
end

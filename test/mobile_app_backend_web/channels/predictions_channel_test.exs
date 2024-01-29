defmodule MobileAppBackendWeb.PredictionsChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import Test.Support.Helpers
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
             "fields[trip]" => "",
             "filter[stop]" => "12345,67890",
             "include" => "trip"
           } = URI.decode_query(query)

    sse_ref = Process.monitor(sse_stub)
    Process.unlink(socket.channel_pid)
    leave_ref = leave(socket)
    assert_reply leave_ref, :ok

    assert_receive {:DOWN, ^sse_ref, :process, ^sse_stub, :shutdown}
  end

  test "correctly handles messages", %{socket: socket} do
    {:ok, reply, socket} =
      subscribe_and_join(socket, "predictions:stops", %{"stop_ids" => ["12345", "67890"]})

    assert reply == %{}

    instance = socket.assigns[:stream_instance]
    sse_stub = SSEStub.get_from_instance(instance)

    SSEStub.push_events(sse_stub, [
      %ServerSentEventStage.Event{
        event: "reset",
        data: """
        [
          {"attributes":{"arrival_time":"2024-01-24T17:11:28-05:00","arrival_uncertainty":60,"departure_time":"2024-01-24T17:12:50-05:00","departure_uncertainty":60,"direction_id":0,"revenue":"REVENUE","schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580230-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580230","type":"trip"}},"vehicle":{"data":{"id":"R-547A75ED","type":"vehicle"}}},"type":"prediction"}
        ]
        """
      }
    ])

    assert_push "stream_events", %{events: [%MBTAV3API.Stream.Event.Reset{data: [_]}]}

    SSEStub.push_events(sse_stub, [
      %ServerSentEventStage.Event{
        event: "add",
        data: """
        {"attributes":{"arrival_time":"2024-01-24T17:16:26-05:00","arrival_uncertainty":60,"departure_time":"2024-01-24T17:17:31-05:00","departure_uncertainty":60,"direction_id":0,"revenue":"REVENUE","schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392521-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392521","type":"trip"}},"vehicle":{"data":{"id":"R-547A7677","type":"vehicle"}}},"type":"prediction"}
        """
      },
      %ServerSentEventStage.Event{
        event: "update",
        data: """
        {"attributes":{"arrival_time":"2024-01-24T17:11:28-05:00","arrival_uncertainty":60,"departure_time":"2024-01-24T17:12:50-05:00","departure_uncertainty":60,"direction_id":0,"revenue":"REVENUE","schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580230-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580230","type":"trip"}},"vehicle":{"data":{"id":"R-547A75ED","type":"vehicle"}}},"type":"prediction"}
        """
      },
      %ServerSentEventStage.Event{
        event: "remove",
        data: """
        {"id":"prediction-ADDED-1591580230-70095-120","type":"prediction"}
        """
      }
    ])

    assert_push "stream_events", %{
      events: [
        %MBTAV3API.Stream.Event.Add{},
        %MBTAV3API.Stream.Event.Update{},
        %MBTAV3API.Stream.Event.Remove{}
      ]
    }
  end
end

defmodule MobileAppBackendWeb.PredictionsChannelTest do
  use MobileAppBackendWeb.ChannelCase

  import Test.Support.Helpers
  import Test.Support.Sigils
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Trip
  alias MBTAV3API.Prediction
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
          {"attributes":{},"id":"60392455","links":{"self":"/trips/60392455"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392456","links":{"self":"/trips/60392456"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392457","links":{"self":"/trips/60392457"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392458","links":{"self":"/trips/60392458"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392459","links":{"self":"/trips/60392459"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392460","links":{"self":"/trips/60392460"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392461","links":{"self":"/trips/60392461"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392515","links":{"self":"/trips/60392515"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392517","links":{"self":"/trips/60392517"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392518","links":{"self":"/trips/60392518"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392519","links":{"self":"/trips/60392519"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392520","links":{"self":"/trips/60392520"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392523","links":{"self":"/trips/60392523"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392589","links":{"self":"/trips/60392589"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"933_0016","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392590","links":{"self":"/trips/60392590"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"933_0016","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392591","links":{"self":"/trips/60392591"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"933_0016","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392648","links":{"self":"/trips/60392648"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"933_0015","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"60392650","links":{"self":"/trips/60392650"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":{"id":"RTL12024-hms14011-Weekday-01","type":"service"}},"shape":{"data":{"id":"933_0015","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591579772","links":{"self":"/trips/ADDED-1591579772"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591579808","links":{"self":"/trips/ADDED-1591579808"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591579876","links":{"self":"/trips/ADDED-1591579876"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591580009","links":{"self":"/trips/ADDED-1591580009"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591580012","links":{"self":"/trips/ADDED-1591580012"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591580101","links":{"self":"/trips/ADDED-1591580101"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591580230","links":{"self":"/trips/ADDED-1591580230"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591587655","links":{"self":"/trips/ADDED-1591587655"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"ADDED-1591587814","links":{"self":"/trips/ADDED-1591587814"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"NONREV-1590724635","links":{"self":"/trips/NONREV-1590724635"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"NONREV-1590724921","links":{"self":"/trips/NONREV-1590724921"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"NONREV-1590731573","links":{"self":"/trips/NONREV-1590731573"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"NONREV-1590732631","links":{"self":"/trips/NONREV-1590732631"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-3-1","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0010","type":"shape"}}},"type":"trip"},
          {"attributes":{},"id":"NONREV-1590735430","links":{"self":"/trips/NONREV-1590735430"},"relationships":{"route":{"data":{"id":"Red","type":"route"}},"route_pattern":{"data":{"id":"Red-1-0","type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-931_0009","type":"shape"}}},"type":"trip"},
          {"attributes":{"arrival_time":"2024-01-30T15:44:09-05:00","departure_time":"2024-01-30T15:45:10-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392455-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392455","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F7","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T15:46:26-05:00","departure_time":"2024-01-30T15:47:48-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392515-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392515","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F8","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T15:49:45-05:00","departure_time":"2024-01-30T15:51:11-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-NONREV-1590731573-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"NONREV-1590731573","type":"trip"}},"vehicle":{"data":{"id":"R-547A7E40","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T15:54:02-05:00","departure_time":"2024-01-30T15:55:43-05:00","direction_id":1,"schedule_relationship":"ADDED","status":null,"stop_sequence":100},"id":"prediction-ADDED-1591587814-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"ADDED-1591587814","type":"trip"}},"vehicle":{"data":{"id":"R-547A7249","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T15:56:52-05:00","departure_time":"2024-01-30T15:57:53-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392456-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392456","type":"trip"}},"vehicle":{"data":{"id":"R-547A8506","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T15:59:53-05:00","departure_time":"2024-01-30T16:01:15-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":130},"id":"prediction-ADDED-1591579772-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"ADDED-1591579772","type":"trip"}},"vehicle":{"data":{"id":"R-547A7CE2","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:06:10-05:00","departure_time":"2024-01-30T16:07:36-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591587655-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591587655","type":"trip"}},"vehicle":{"data":{"id":"R-547A7B21","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:07:00-05:00","departure_time":"2024-01-30T16:08:41-05:00","direction_id":1,"schedule_relationship":"ADDED","status":null,"stop_sequence":100},"id":"prediction-ADDED-1591580101-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580101","type":"trip"}},"vehicle":{"data":{"id":"R-547A6F24","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:12:52-05:00","departure_time":"2024-01-30T16:13:53-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392457-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392457","type":"trip"}},"vehicle":{"data":{"id":"R-547A83E8","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:14:02-05:00","departure_time":"2024-01-30T16:15:24-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392517-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392517","type":"trip"}},"vehicle":{"data":{"id":"R-547A83D9","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:17:58-05:00","departure_time":"2024-01-30T16:19:39-05:00","direction_id":1,"schedule_relationship":"ADDED","status":null,"stop_sequence":100},"id":"prediction-ADDED-1591579808-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"ADDED-1591579808","type":"trip"}},"vehicle":{"data":{"id":"R-547A7BD1","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:20:54-05:00","departure_time":"2024-01-30T16:22:20-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-NONREV-1590724635-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"NONREV-1590724635","type":"trip"}},"vehicle":{"data":{"id":"R-547A7B60","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:28:52-05:00","departure_time":"2024-01-30T16:29:53-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392458-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392458","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F8","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:30:08-05:00","departure_time":"2024-01-30T16:31:30-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392518-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392518","type":"trip"}},"vehicle":{"data":{"id":"R-547A84CE","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:37:57-05:00","departure_time":"2024-01-30T16:39:23-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":120},"id":"prediction-60392648-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"60392648","type":"trip"}},"vehicle":{"data":{"id":"R-547A80A3","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:44:52-05:00","departure_time":"2024-01-30T16:45:53-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392459-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392459","type":"trip"}},"vehicle":{"data":{"id":"R-547A7CE2","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:46:08-05:00","departure_time":"2024-01-30T16:47:30-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392519-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392519","type":"trip"}},"vehicle":{"data":{"id":"R-547A83DB","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:49:58-05:00","departure_time":"2024-01-30T16:51:39-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":100},"id":"prediction-60392589-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"60392589","type":"trip"}},"vehicle":{"data":{"id":"R-547A83E5","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T16:57:32-05:00","departure_time":"2024-01-30T16:58:58-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591579876-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591579876","type":"trip"}},"vehicle":{"data":{"id":"R-547A7842","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:00:52-05:00","departure_time":"2024-01-30T17:01:53-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392460-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392460","type":"trip"}},"vehicle":{"data":{"id":"R-547A83D9","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:02:14-05:00","departure_time":"2024-01-30T17:03:36-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392520-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392520","type":"trip"}},"vehicle":{"data":{"id":"R-547A83E3","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:05:58-05:00","departure_time":"2024-01-30T17:07:39-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":100},"id":"prediction-60392590-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"60392590","type":"trip"}},"vehicle":{"data":{"id":"R-547A7E40","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:09:57-05:00","departure_time":"2024-01-30T17:11:23-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580230-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580230","type":"trip"}},"vehicle":{"data":{"id":"R-547A7A21","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:16:52-05:00","departure_time":"2024-01-30T17:17:53-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392461-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392461","type":"trip"}},"vehicle":{"data":{"id":"R-547A84CE","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:18:08-05:00","departure_time":"2024-01-30T17:19:30-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":130},"id":"prediction-NONREV-1590735430-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"NONREV-1590735430","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F7","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:21:58-05:00","departure_time":"2024-01-30T17:23:39-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":100},"id":"prediction-60392591-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"60392591","type":"trip"}},"vehicle":{"data":{"id":"R-547A7B21","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:25:57-05:00","departure_time":"2024-01-30T17:27:23-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":120},"id":"prediction-60392650-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"60392650","type":"trip"}},"vehicle":{"data":{"id":"R-547A7249","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:34:08-05:00","departure_time":"2024-01-30T17:35:30-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":130},"id":"prediction-NONREV-1590724921-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"NONREV-1590724921","type":"trip"}},"vehicle":{"data":{"id":"R-547A8506","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:37:58-05:00","departure_time":"2024-01-30T17:39:39-05:00","direction_id":1,"schedule_relationship":"ADDED","status":null,"stop_sequence":100},"id":"prediction-NONREV-1590732631-70096-100","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70096","type":"stop"}},"trip":{"data":{"id":"NONREV-1590732631","type":"trip"}},"vehicle":{"data":{"id":"R-547A7B60","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:39:57-05:00","departure_time":"2024-01-30T17:41:23-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580012-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580012","type":"trip"}},"vehicle":{"data":{"id":"R-547A6F24","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:48:08-05:00","departure_time":"2024-01-30T17:49:30-05:00","direction_id":0,"schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392523-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392523","type":"trip"}},"vehicle":{"data":{"id":"R-547A83E8","type":"vehicle"}}},"type":"prediction"},
          {"attributes":{"arrival_time":"2024-01-30T17:55:57-05:00","departure_time":"2024-01-30T17:57:23-05:00","direction_id":0,"schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580009-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580009","type":"trip"}},"vehicle":{"data":{"id":"R-547A7BD1","type":"vehicle"}}},"type":"prediction"}
        ]
        """
      }
    ])

    assert_push "stream_data", %{predictions: predictions}
    assert length(predictions) == 32

    assert Enum.find(predictions, &(&1.id == "prediction-60392455-70086-90")) ==
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

    SSEStub.push_events(sse_stub, [
      %ServerSentEventStage.Event{
        event: "update",
        data: """
        {"attributes":{"arrival_time":"2024-01-30T15:44:26-05:00","departure_time":"2024-01-30T15:45:27-05:00","direction_id":1,"schedule_relationship":null,"status":null,"stop_sequence":90},"id":"prediction-60392455-70086-90","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70086","type":"stop"}},"trip":{"data":{"id":"60392455","type":"trip"}},"vehicle":{"data":{"id":"R-547A83F7","type":"vehicle"}}},"type":"prediction"}
        """
      },
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
      },
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
    assert length(predictions) == 32

    assert Enum.find(predictions, &(&1.id == "prediction-60392455-70086-90")) == %Prediction{
             id: "prediction-60392455-70086-90",
             arrival_time: ~B[2024-01-30 15:44:26],
             departure_time: ~B[2024-01-30 15:45:27],
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

    refute Enum.find(predictions, &(&1.id == "prediction-60392515-70085-130"))

    assert Enum.find(predictions, &(&1.id == "prediction-60392593-70096-100")) == %Prediction{
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
  end
end

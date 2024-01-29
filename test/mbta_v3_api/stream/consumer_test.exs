defmodule MBTAV3API.Stream.ConsumerTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction
  alias MBTAV3API.Stream
  alias MBTAV3API.Trip

  test "parses events and sends messages" do
    {:ok, producer} =
      GenStage.from_enumerable([
        %ServerSentEventStage.Event{
          event: "reset",
          data: """
          [
            {"attributes":{},"id":"ADDED-1591580230","links":{"self":"/trips/ADDED-1591580230"},"relationships":{"route":{"data":{"id":"Red", "type":"route"}},"route_pattern":{"data":{"id":"Red-3-0", "type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009", "type":"shape"}}},"type":"trip"},
            {"attributes":{"arrival_time":"2024-01-24T17:11:28-05:00","arrival_uncertainty":60,"departure_time":"2024-01-24T17:12:50-05:00","departure_uncertainty":60,"direction_id":0,"revenue":"REVENUE","schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580230-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580230","type":"trip"}},"vehicle":{"data":{"id":"R-547A75ED","type":"vehicle"}}},"type":"prediction"}
          ]
          """
        },
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

    _consumer = start_supervised!({Stream.Consumer, subscribe_to: [producer], send_to: self()})

    assert_receive {:stream_events,
                    [
                      %Stream.Event.Reset{data: [%Trip{}, %Prediction{}]},
                      %Stream.Event.Add{data: %Prediction{}},
                      %Stream.Event.Update{data: %Prediction{}},
                      %Stream.Event.Remove{data: %JsonApi.Reference{}}
                    ]}
  end
end

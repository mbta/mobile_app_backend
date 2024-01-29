defmodule MBTAV3API.Stream.EventTest do
  use ExUnit.Case, async: true

  import Test.Support.Sigils

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction
  alias MBTAV3API.Stream.Event
  alias MBTAV3API.Trip
  alias ServerSentEventStage.Event, as: RawEvent

  describe "parse/1" do
    test "parses reset" do
      result =
        Event.parse(%RawEvent{
          event: "reset",
          data: """
          [
            {"attributes":{},"id":"ADDED-1591580230","links":{"self":"/trips/ADDED-1591580230"},"relationships":{"route":{"data":{"id":"Red", "type":"route"}},"route_pattern":{"data":{"id":"Red-3-0", "type":"route_pattern"}},"service":{"data":null},"shape":{"data":{"id":"canonical-933_0009", "type":"shape"}}},"type":"trip"},
            {"attributes":{"arrival_time":"2024-01-24T17:11:28-05:00","arrival_uncertainty":60,"departure_time":"2024-01-24T17:12:50-05:00","departure_uncertainty":60,"direction_id":0,"revenue":"REVENUE","schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580230-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580230","type":"trip"}},"vehicle":{"data":{"id":"R-547A75ED","type":"vehicle"}}},"type":"prediction"}
          ]
          """
        })

      assert result == %Event.Reset{
               data: [
                 %Trip{
                   id: "ADDED-1591580230",
                   route_pattern: %JsonApi.Reference{type: "route_pattern", id: "Red-3-0"}
                 },
                 %Prediction{
                   id: "prediction-ADDED-1591580230-70095-120",
                   arrival_time: ~B[2024-01-24 17:11:28],
                   departure_time: ~B[2024-01-24 17:12:50],
                   direction_id: 0,
                   revenue: true,
                   schedule_relationship: :added,
                   status: nil,
                   stop_sequence: 120,
                   trip: %Trip{
                     id: "ADDED-1591580230",
                     route_pattern: %JsonApi.Reference{type: "route_pattern", id: "Red-3-0"}
                   }
                 }
               ]
             }
    end

    test "parses add" do
      result =
        Event.parse(%RawEvent{
          event: "add",
          data: """
          {"attributes":{"arrival_time":"2024-01-24T17:16:26-05:00","arrival_uncertainty":60,"departure_time":"2024-01-24T17:17:31-05:00","departure_uncertainty":60,"direction_id":0,"revenue":"REVENUE","schedule_relationship":null,"status":null,"stop_sequence":130},"id":"prediction-60392521-70085-130","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70085","type":"stop"}},"trip":{"data":{"id":"60392521","type":"trip"}},"vehicle":{"data":{"id":"R-547A7677","type":"vehicle"}}},"type":"prediction"}
          """
        })

      assert result == %Event.Add{
               data: %Prediction{
                 id: "prediction-60392521-70085-130",
                 arrival_time: ~B[2024-01-24 17:16:26],
                 departure_time: ~B[2024-01-24 17:17:31],
                 direction_id: 0,
                 revenue: true,
                 schedule_relationship: :scheduled,
                 status: nil,
                 stop_sequence: 130,
                 trip: %JsonApi.Reference{type: "trip", id: "60392521"}
               }
             }
    end

    test "parses update" do
      result =
        Event.parse(%RawEvent{
          event: "update",
          data: """
          {"attributes":{"arrival_time":"2024-01-24T17:11:28-05:00","arrival_uncertainty":60,"departure_time":"2024-01-24T17:12:50-05:00","departure_uncertainty":60,"direction_id":0,"revenue":"REVENUE","schedule_relationship":"ADDED","status":null,"stop_sequence":120},"id":"prediction-ADDED-1591580230-70095-120","relationships":{"route":{"data":{"id":"Red","type":"route"}},"stop":{"data":{"id":"70095","type":"stop"}},"trip":{"data":{"id":"ADDED-1591580230","type":"trip"}},"vehicle":{"data":{"id":"R-547A75ED","type":"vehicle"}}},"type":"prediction"}
          """
        })

      assert result == %Event.Update{
               data: %Prediction{
                 id: "prediction-ADDED-1591580230-70095-120",
                 arrival_time: ~B[2024-01-24 17:11:28],
                 departure_time: ~B[2024-01-24 17:12:50],
                 direction_id: 0,
                 revenue: true,
                 schedule_relationship: :added,
                 status: nil,
                 stop_sequence: 120,
                 trip: %JsonApi.Reference{type: "trip", id: "ADDED-1591580230"}
               }
             }
    end

    test "parses remove" do
      result =
        Event.parse(%RawEvent{
          event: "remove",
          data: """
          {"id":"prediction-ADDED-1591580230-70095-120","type":"prediction"}
          """
        })

      assert result == %Event.Remove{
               data: %JsonApi.Reference{
                 type: "prediction",
                 id: "prediction-ADDED-1591580230-70095-120"
               }
             }
    end
  end
end

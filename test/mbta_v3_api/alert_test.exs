defmodule MBTAV3API.AlertTest do
  use ExUnit.Case

  import Mox

  alias MBTAV3API.{Alert, JsonApi}
  import Test.Support.Sigils

  setup :verify_on_exit!

  describe "active?/1" do
    test "true if in single active period" do
      assert Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:44:04],
                     end: ~B[2024-02-12 10:44:04]
                   }
                 ]
               },
               ~B[2024-02-12 09:44:28]
             )
    end

    test "false if outside single active period" do
      refute Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:45:04],
                     end: ~B[2024-02-12 09:45:10]
                   }
                 ]
               },
               ~B[2024-02-12 09:45:18]
             )
    end

    test "true if inside one of many active periods" do
      assert Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:00:00],
                     end: ~B[2024-02-12 10:00:00]
                   },
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 11:00:00],
                     end: ~B[2024-02-12 12:00:00]
                   }
                 ]
               },
               ~B[2024-02-12 11:22:33]
             )
    end

    test "false if outside each of many active periods" do
      refute Alert.active?(
               %Alert{
                 active_period: [
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 09:00:00],
                     end: ~B[2024-02-12 10:00:00]
                   },
                   %Alert.ActivePeriod{
                     start: ~B[2024-02-12 11:00:00],
                     end: ~B[2024-02-12 12:00:00]
                   }
                 ]
               },
               ~B[2024-02-12 10:20:30]
             )
    end
  end

  test "parse!/1" do
    assert Alert.parse!(%JsonApi.Item{
             id: "553407",
             attributes: %{
               "active_period" => [
                 %{"start" => "2024-02-12T11:49:00-05:00", "end" => "2024-02-12T14:26:40-05:00"}
               ],
               "cause" => "FIRE",
               "description" => "Description",
               "duration_certainty" => "ESTIMATED",
               "effect" => "DELAY",
               "header" => "Header",
               "informed_entity" => [
                 %{"activities" => ["BOARD", "EXIT", "RIDE"], "route" => "39", "route_type" => 3}
               ],
               "lifecycle" => "NEW",
               "severity" => 7,
               "updated_at" => "2024-02-12T11:49:00-05:00"
             }
           }) == %Alert{
             id: "553407",
             active_period: [
               %Alert.ActivePeriod{start: ~B[2024-02-12 11:49:00], end: ~B[2024-02-12 14:26:40]}
             ],
             cause: :fire,
             description: "Description",
             duration_certainty: :estimated,
             effect: :delay,
             header: "Header",
             informed_entity: [
               %Alert.InformedEntity{
                 activities: [:board, :exit, :ride],
                 route: "39",
                 route_type: :bus
               }
             ],
             lifecycle: :new,
             severity: 7,
             updated_at: ~B[2024-02-12 11:49:00]
           }
  end

  test "unexpected enum values fall back" do
    assert Alert.parse!(%JsonApi.Item{
             id: "553407",
             attributes: %{
               "active_period" => [
                 %{"start" => "2024-02-12T11:49:00-05:00", "end" => "2024-02-12T14:26:40-05:00"}
               ],
               "cause" => "ALIENS",
               "description" => "Description",
               "duration_certainty" => "BEYOND_MORTAL_COMPREHENSION",
               "effect" => "TELEPORTATION",
               "header" => "Header",
               "informed_entity" => [
                 %{"activities" => ["BOARD", "EXIT", "RIDE"], "route" => "39", "route_type" => 3}
               ],
               "lifecycle" => "NEW",
               "updated_at" => "2024-02-12T11:49:00-05:00"
             }
           }) == %Alert{
             id: "553407",
             active_period: [
               %Alert.ActivePeriod{start: ~B[2024-02-12 11:49:00], end: ~B[2024-02-12 14:26:40]}
             ],
             cause: :unknown_cause,
             description: "Description",
             duration_certainty: :unknown,
             effect: :unknown_effect,
             header: "Header",
             informed_entity: [
               %Alert.InformedEntity{
                 activities: [:board, :exit, :ride],
                 route: "39",
                 route_type: :bus
               }
             ],
             lifecycle: :new,
             updated_at: ~B[2024-02-12 11:49:00]
           }
  end

  test "collapses adjacent active periods" do
    assert Alert.parse!(%JsonApi.Item{
             id: "630418",
             attributes: %{
               "active_period" => [
                 %{"start" => "2025-03-28T03:00:00-04:00", "end" => "2025-03-29T02:59:00-04:00"},
                 %{"start" => "2025-03-29T03:00:00-04:00", "end" => "2025-03-30T02:59:00-04:00"},
                 %{"start" => "2025-03-30T03:00:00-04:00", "end" => "2025-03-31T02:59:00-04:00"},
                 %{"start" => "2025-03-31T03:00:00-04:00", "end" => "2025-04-01T02:59:00-04:00"},
                 %{"start" => "2025-04-01T03:00:00-04:00", "end" => "2025-04-02T02:59:00-04:00"},
                 %{"start" => "2025-04-02T03:00:00-04:00", "end" => "2025-04-03T02:59:00-04:00"},
                 %{"start" => "2025-04-03T03:00:00-04:00", "end" => "2025-04-04T02:59:00-04:00"},
                 %{"start" => "2025-04-04T03:00:00-04:00", "end" => "2025-04-05T02:59:00-04:00"},
                 %{"start" => "2025-04-05T03:00:00-04:00", "end" => "2025-04-06T02:59:00-04:00"},
                 %{"start" => "2025-04-06T03:00:00-04:00", "end" => "2025-04-07T02:59:00-04:00"},
                 %{"start" => "2025-04-07T03:00:00-04:00", "end" => "2025-04-08T02:59:00-04:00"},
                 %{"start" => "2025-04-08T03:00:00-04:00", "end" => "2025-04-09T02:59:00-04:00"},
                 %{"start" => "2025-04-09T03:00:00-04:00", "end" => "2025-04-10T02:59:00-04:00"},
                 %{"start" => "2025-04-10T03:00:00-04:00", "end" => "2025-04-11T02:59:00-04:00"},
                 %{"start" => "2025-04-11T03:00:00-04:00", "end" => "2025-04-12T02:59:00-04:00"},
                 %{"start" => "2025-04-12T03:00:00-04:00", "end" => "2025-04-13T02:59:00-04:00"},
                 %{"start" => "2025-04-13T03:00:00-04:00", "end" => "2025-04-14T02:59:00-04:00"},
                 %{"start" => "2025-04-14T03:00:00-04:00", "end" => "2025-04-15T02:59:00-04:00"},
                 %{"start" => "2025-04-15T03:00:00-04:00", "end" => "2025-04-16T02:59:00-04:00"},
                 %{"start" => "2025-04-16T03:00:00-04:00", "end" => "2025-04-17T02:59:00-04:00"},
                 %{"start" => "2025-04-17T03:00:00-04:00", "end" => "2025-04-18T02:59:00-04:00"},
                 %{"start" => "2025-04-18T03:00:00-04:00", "end" => "2025-04-19T02:59:00-04:00"},
                 %{"start" => "2025-04-19T03:00:00-04:00", "end" => "2025-04-20T02:59:00-04:00"},
                 %{"start" => "2025-04-20T03:00:00-04:00", "end" => "2025-04-21T02:59:00-04:00"},
                 %{"start" => "2025-04-21T03:00:00-04:00", "end" => "2025-04-22T02:59:00-04:00"},
                 %{"start" => "2025-04-22T03:00:00-04:00", "end" => "2025-04-23T02:59:00-04:00"},
                 %{"start" => "2025-04-23T03:00:00-04:00", "end" => "2025-04-24T02:59:00-04:00"},
                 %{"start" => "2025-04-24T03:00:00-04:00", "end" => "2025-04-25T02:59:00-04:00"},
                 %{"start" => "2025-04-25T03:00:00-04:00", "end" => "2025-04-26T02:59:00-04:00"},
                 %{"start" => "2025-04-26T03:00:00-04:00", "end" => "2025-04-27T02:59:00-04:00"},
                 %{"start" => "2025-04-27T03:00:00-04:00", "end" => "2025-04-28T02:59:00-04:00"},
                 %{"start" => "2025-04-28T03:00:00-04:00", "end" => "2025-04-29T02:59:00-04:00"},
                 %{"start" => "2025-04-29T03:00:00-04:00", "end" => "2025-04-30T02:59:00-04:00"},
                 %{"start" => "2025-04-30T03:00:00-04:00", "end" => "2025-05-01T02:59:00-04:00"},
                 %{"start" => "2025-05-01T03:00:00-04:00", "end" => "2025-05-02T02:59:00-04:00"},
                 %{"start" => "2025-05-02T03:00:00-04:00", "end" => "2025-05-03T02:59:00-04:00"},
                 %{"start" => "2025-05-03T03:00:00-04:00", "end" => "2025-05-04T02:59:00-04:00"},
                 %{"start" => "2025-05-04T03:00:00-04:00", "end" => "2025-05-05T02:59:00-04:00"},
                 %{"start" => "2025-05-05T03:00:00-04:00", "end" => "2025-05-06T02:59:00-04:00"},
                 %{"start" => "2025-05-06T03:00:00-04:00", "end" => "2025-05-07T02:59:00-04:00"},
                 %{"start" => "2025-05-07T03:00:00-04:00", "end" => "2025-05-08T02:59:00-04:00"},
                 %{"start" => "2025-05-08T03:00:00-04:00", "end" => "2025-05-09T02:59:00-04:00"},
                 %{"start" => "2025-05-09T03:00:00-04:00", "end" => "2025-05-10T02:59:00-04:00"},
                 %{"start" => "2025-05-10T03:00:00-04:00", "end" => "2025-05-11T02:59:00-04:00"},
                 %{"start" => "2025-05-11T03:00:00-04:00", "end" => "2025-05-12T02:59:00-04:00"}
               ],
               "cause" => "CONSTRUCTION",
               "description" => "Description",
               "duration_certainty" => "KNOWN",
               "effect" => "STOP_CLOSURE",
               "header" => "Header",
               "informed_entity" => [
                 %{
                   "activities" => ["BOARD", "EXIT"],
                   "route" => "47",
                   "route_type" => 3,
                   "stop" => "1123"
                 }
               ],
               "lifecycle" => "NEW",
               "severity" => 5,
               "updated_at" => "2025-03-17T15:17:11-04:00"
             }
           }) == %Alert{
             id: "630418",
             active_period: [
               %Alert.ActivePeriod{start: ~B[2025-03-28 03:00:00], end: ~B[2025-05-12 02:59:00]}
             ],
             cause: :construction,
             description: "Description",
             duration_certainty: :known,
             effect: :stop_closure,
             header: "Header",
             informed_entity: [
               %Alert.InformedEntity{
                 activities: [:board, :exit],
                 route: "47",
                 route_type: :bus,
                 stop: "1123"
               }
             ],
             lifecycle: :new,
             severity: 5,
             updated_at: ~B[2025-03-17 15:17:11]
           }
  end
end

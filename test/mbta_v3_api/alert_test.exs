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
end

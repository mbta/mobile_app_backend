defmodule MBTAV3API.AlertTest do
  use ExUnit.Case

  import Mox

  alias MBTAV3API.{Alert, JsonApi, Repository}
  import Test.Support.Sigils

  setup :verify_on_exit!

  test "get_all/1" do
    expect(
      MobileAppBackend.HTTPMock,
      :request,
      fn %Req.Request{url: %URI{path: "/alerts"}, options: %{params: params}} ->
        assert params == %{
                 "fields[alert]" =>
                   "active_period,cause,description,effect,effect_name,header,informed_entity,lifecycle,updated_at",
                 "filter[lifecycle]" => "NEW,ONGOING,ONGOING_UPCOMING",
                 "filter[stop]" =>
                   "9983,6542,1241,8281,place-boyls,8279,49002,6565,place-tumnl,145,place-pktrm,place-bbsta"
               }

        {:ok,
         Req.Response.json(%{
           data: [
             %{
               "attributes" => %{
                 "active_period" => [
                   %{"end" => "2024-02-08T19:12:40-05:00", "start" => "2024-02-08T14:38:00-05:00"}
                 ],
                 "cause" => "UNKNOWN_CAUSE",
                 "description" => "Description 1",
                 "effect" => "DELAY",
                 "header" => "Header 1",
                 "informed_entity" => [
                   %{
                     "activities" => ["BOARD", "EXIT", "RIDE"],
                     "route" => "11",
                     "route_type" => 3
                   }
                 ],
                 "lifecycle" => "NEW",
                 "updated_at" => "2024-02-08T14:38:00-05:00"
               },
               "id" => "552825",
               "links" => %{"self" => "/alerts/552825"},
               "type" => "alert"
             },
             %{
               "attributes" => %{
                 "active_period" => [
                   %{"end" => "2024-02-08T19:12:40-05:00", "start" => "2024-02-08T12:55:00-05:00"}
                 ],
                 "cause" => "UNRULY_PASSENGER",
                 "description" => "Description 2",
                 "effect" => "DELAY",
                 "header" => "Header 2",
                 "informed_entity" => [
                   %{
                     "activities" => ["BOARD", "EXIT", "RIDE"],
                     "route" => "15",
                     "route_type" => 3
                   }
                 ],
                 "lifecycle" => "NEW",
                 "updated_at" => "2024-02-08T12:55:00-05:00"
               },
               "id" => "552803",
               "links" => %{"self" => "/alerts/552803"},
               "type" => "alert"
             }
           ]
         })}
      end
    )

    {:ok, %{data: alerts}} =
      Repository.alerts(
        filter: [
          lifecycle: [:new, :ongoing, :ongoing_upcoming],
          stop: [
            "9983",
            "6542",
            "1241",
            "8281",
            "place-boyls",
            "8279",
            "49002",
            "6565",
            "place-tumnl",
            "145",
            "place-pktrm",
            "place-bbsta"
          ]
        ]
      )

    assert alerts == [
             %Alert{
               id: "552825",
               active_period: [
                 %Alert.ActivePeriod{start: ~B[2024-02-08 14:38:00], end: ~B[2024-02-08 19:12:40]}
               ],
               cause: :unknown_cause,
               description: "Description 1",
               effect: :delay,
               header: "Header 1",
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "11",
                   route_type: :bus
                 }
               ],
               lifecycle: :new,
               updated_at: ~B[2024-02-08 14:38:00]
             },
             %Alert{
               id: "552803",
               active_period: [
                 %Alert.ActivePeriod{start: ~B[2024-02-08 12:55:00], end: ~B[2024-02-08 19:12:40]}
               ],
               cause: :unruly_passenger,
               description: "Description 2",
               effect: :delay,
               header: "Header 2",
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "15",
                   route_type: :bus
                 }
               ],
               lifecycle: :new,
               updated_at: ~B[2024-02-08 12:55:00]
             }
           ]
  end

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

  test "parse/1" do
    assert Alert.parse(%JsonApi.Item{
             id: "553407",
             attributes: %{
               "active_period" => [
                 %{"start" => "2024-02-12T11:49:00-05:00", "end" => "2024-02-12T14:26:40-05:00"}
               ],
               "cause" => "FIRE",
               "description" => "Description",
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
    assert Alert.parse(%JsonApi.Item{
             id: "553407",
             attributes: %{
               "active_period" => [
                 %{"start" => "2024-02-12T11:49:00-05:00", "end" => "2024-02-12T14:26:40-05:00"}
               ],
               "cause" => "ALIENS",
               "description" => "Description",
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

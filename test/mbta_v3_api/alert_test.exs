defmodule MBTAV3API.AlertTest do
  use ExUnit.Case

  alias MBTAV3API.Alert
  import Test.Support.Sigils

  setup do
    Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
    :ok
  end

  test "get_all/1" do
    {:ok, alerts} =
      Alert.get_all(
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
               effect: :delay,
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "11",
                   route_type: :bus
                 }
               ],
               lifecycle: :new
             },
             %Alert{
               id: "552803",
               active_period: [
                 %Alert.ActivePeriod{start: ~B[2024-02-08 12:55:00], end: ~B[2024-02-08 19:12:40]}
               ],
               effect: :delay,
               informed_entity: [
                 %Alert.InformedEntity{
                   activities: [:board, :exit, :ride],
                   route: "15",
                   route_type: :bus
                 }
               ],
               lifecycle: :new
             }
           ]
  end
end

defmodule MobileAppBackend.Alerts.FormattedAlert.TemplateFragmentsTest do
  use ExUnit.Case, async: true
  import Test.Support.Sigils
  alias MobileAppBackend.Alerts.FormattedAlert
  alias MobileAppBackend.Alerts.FormattedAlert.TemplateFragments

  alias MobileAppBackend.Alerts.AlertSummary.{
    Direction,
    Location,
    Recurrence,
    Timeframe,
    TripSpecific
  }

  alias MobileAppBackend.Alerts.AlertSummary.Timeframe.TimeRange.{EndOfService, StartOfService}

  describe "location/2" do
    test "direction to stop" do
      assert " from **Northbound** stops to **Downtown Crossing**" ==
               TemplateFragments.location(:suspension, %Location.DirectionToStop{
                 direction: %Direction{name: "North", destination: "Oak Grove"},
                 end_stop_name: "Downtown Crossing"
               })
    end

    test "single stop" do
      assert " at **Downtown Crossing**" ==
               TemplateFragments.location(:suspension, %Location.SingleStop{
                 stop_name: "Downtown Crossing",
                 downstream: false
               })
    end

    test "stop to direction" do
      assert " from **Downtown Crossing** to **Northbound** stops" ==
               TemplateFragments.location(:suspension, %Location.StopToDirection{
                 direction: %Direction{name: "North", destination: "Oak Grove"},
                 start_stop_name: "Downtown Crossing"
               })
    end

    test "successive stops" do
      assert " from **Downtown Crossing** to **Oak Grove**" ==
               TemplateFragments.location(:suspension, %Location.SuccessiveStops{
                 start_stop_name: "Downtown Crossing",
                 end_stop_name: "Oak Grove"
               })
    end

    test "whole route shuttle" do
      assert " replacing **Red Line**" ==
               TemplateFragments.location(:shuttle, %Location.WholeRoute{
                 route_label: "Red Line",
                 route_type: :heavy_rail
               })
    end

    test "whole route other" do
      assert " on **Red Line**" ==
               TemplateFragments.location(:suspension, %Location.WholeRoute{
                 route_label: "Red Line",
                 route_type: :heavy_rail
               })
    end

    test "whole route bus" do
      assert " on **132 bus**" ==
               TemplateFragments.location(:suspension, %Location.WholeRoute{
                 route_label: "132",
                 route_type: :bus
               })
    end
  end

  describe "summary_timeframe/1" do
    test "until further notice" do
      assert " until further notice" ==
               TemplateFragments.timeframe(%Timeframe.UntilFurtherNotice{})
    end

    test "end of service" do
      assert " through end of service" ==
               TemplateFragments.timeframe(%Timeframe.EndOfService{})
    end

    test "tomorrow" do
      assert " through tomorrow" == TemplateFragments.timeframe(%Timeframe.Tomorrow{})
    end

    test "later date" do
      assert " through Apr 29" ==
               TemplateFragments.timeframe(%Timeframe.LaterDate{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    test "this week" do
      assert " through Wednesday" ==
               TemplateFragments.timeframe(%Timeframe.ThisWeek{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    test "time" do
      assert " through 10:31 AM" ==
               TemplateFragments.timeframe(%Timeframe.Time{time: ~B[2026-04-29 10:31:00]})
    end

    test "starting tomorrow" do
      assert " starting tomorrow" ==
               TemplateFragments.timeframe(%Timeframe.StartingTomorrow{})
    end

    test "starting later today" do
      assert " starting **10:31 AM** today" ==
               TemplateFragments.timeframe(%Timeframe.StartingLaterToday{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    test "time range - start of service to end" do
      assert " from start of service to end of service" ==
               TemplateFragments.timeframe(%Timeframe.TimeRange{
                 start_time: %StartOfService{},
                 end_time: %EndOfService{}
               })
    end

    test "time range - time to time" do
      assert " from 10:31 AM to 2:31 PM" ==
               TemplateFragments.timeframe(%Timeframe.TimeRange{
                 start_time: %Timeframe.TimeRange.Time{time: ~B[2026-04-29 10:31:00]},
                 end_time: %Timeframe.TimeRange.Time{time: ~B[2026-04-29 14:31:00]}
               })
    end
  end

  describe "summary_recurrence/1" do
    test "daily until further notice" do
      assert " daily until further notice" =
               TemplateFragments.recurrence(%Recurrence.Daily{
                 ending: %Timeframe.UntilFurtherNotice{}
               })
    end

    test "some days until later date" do
      assert " some days until Apr 29" =
               TemplateFragments.recurrence(%Recurrence.SomeDays{
                 ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}
               })
    end

    test "some days through this week" do
      assert " some days until Wednesday" =
               TemplateFragments.recurrence(%Recurrence.SomeDays{
                 ending: %Timeframe.ThisWeek{time: ~B[2026-04-29 10:31:00]}
               })
    end
  end

  describe "summary_trip_effect/4" do
    test "multiple cancelled" do
      summary =
        TemplateFragments.trip_effect(
          %TripSpecific.MultipleTrips{},
          :cancellation,
          nil,
          true
        )

      assert "are cancelled today" == summary
    end

    test "one cancelled" do
      summary =
        TemplateFragments.trip_effect(
          %TripSpecific.TripFrom{
            trip_time: ~B[2026-04-29 10:31:00],
            route_type: :commuter_rail,
            stop_name: "Oak Grove"
          },
          :cancellation,
          nil,
          false
        )

      assert "is cancelled tomorrow" == summary
    end

    test "multiple stops closed" do
      summary =
        TemplateFragments.trip_effect(
          %TripSpecific.TripFrom{
            trip_time: ~B[2026-04-29 10:31:00],
            route_type: :commuter_rail,
            stop_name: "Oak Grove"
          },
          :station_closure,
          ["A", "B", "C"],
          false
        )

      assert "will not stop at **A**, **B**, and **C** tomorrow" == summary
    end

    test "one stop closed" do
      summary =
        TemplateFragments.trip_effect(
          %TripSpecific.TripFrom{
            trip_time: ~B[2026-04-29 10:31:00],
            route_type: :commuter_rail,
            stop_name: "Oak Grove"
          },
          :station_closure,
          ["A"],
          false
        )

      assert "will not stop at **A** tomorrow" == summary
    end

    test "multiple suspended" do
      summary =
        TemplateFragments.trip_effect(
          %TripSpecific.MultipleTrips{},
          :suspension,
          nil,
          true
        )

      assert "are suspended today" == summary
    end

    test "one suspended" do
      summary =
        TemplateFragments.trip_effect(
          %TripSpecific.TripFrom{
            trip_time: ~B[2026-04-29 10:31:00],
            route_type: :commuter_rail,
            stop_name: "Oak Grove"
          },
          :suspension,
          nil,
          true
        )

      assert "is suspended today" == summary
    end

    test "fallback" do
      summary =
        TemplateFragments.trip_effect(
          %TripSpecific.TripFrom{
            trip_time: ~B[2026-04-29 10:31:00],
            route_type: :commuter_rail,
            stop_name: "Oak Grove"
          },
          :modified_service,
          nil,
          true
        )

      assert "affected by Modified service today" == summary
    end
  end
end

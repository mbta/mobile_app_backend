defmodule MobileAppBackend.Alerts.FormattedAlertTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory
  import Mox
  import Test.Support.Helpers
  import Test.Support.Sigils
  require Jason.Sigil
  alias MobileAppBackend.Alerts.AlertSummary.Timeframe.TimeRange.EndOfService
  alias MobileAppBackend.Alerts.AlertSummary.Timeframe.TimeRange.StartOfService
  alias MobileAppBackend.Alerts.FormattedAlert
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.Direction
  alias MobileAppBackend.Alerts.AlertSummary.Location
  alias MobileAppBackend.Alerts.AlertSummary.Recurrence

  alias MobileAppBackend.Alerts.AlertSummary.Timeframe

  alias MobileAppBackend.Alerts.AlertSummary.TripShuttle

  alias MobileAppBackend.Alerts.AlertSummary.TripSpecific

  describe "summary/2 all_clear" do
  end

  describe "summary/2 standard" do
  end

  describe "summary/2 trip-specific" do
  end

  describe "summary/2 trip-shuttle" do
  end

  describe "summary/2 unknown" do
  end

  describe "summary_location/2" do
    test "direction to stop" do
    end

    test "single stop" do
    end

    test "stop to direction" do
    end

    test "successive stops" do
    end

    test "whole route shuttle" do
    end

    test "whole route other" do
    end
  end

  describe "summary_timeframe/1" do
    test "until further notice" do
      assert " until further notice" ==
               FormattedAlert.summary_timeframe(%Timeframe.UntilFurtherNotice{})
    end

    test "end of service" do
      assert " through end of service" ==
               FormattedAlert.summary_timeframe(%Timeframe.EndOfService{})
    end

    test "tomorrow" do
      assert " through tomorrow" == FormattedAlert.summary_timeframe(%Timeframe.Tomorrow{})
    end

    # TODO: time formatting
    @tag :skip
    test "later date" do
      assert " through Apr 29" ==
               FormattedAlert.summary_timeframe(%Timeframe.LaterDate{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    # TODO: time formatting
    @tag :skip
    test "this week" do
      assert " through Wednesday" ==
               FormattedAlert.summary_timeframe(%Timeframe.ThisWeek{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    # TODO: time formatting
    @tag :skip
    test "time" do
      assert " through 10:31 AM" ==
               FormattedAlert.summary_timeframe(%Timeframe.Time{time: ~B[2026-04-29 10:31:00]})
    end

    test "starting tomorrow" do
      assert " starting tomorrow" ==
               FormattedAlert.summary_timeframe(%Timeframe.StartingTomorrow{})
    end

    # TODO: time formatting
    @tag :skip
    test "starting later today" do
      assert " starting **10:31 AM**" ==
               FormattedAlert.summary_timeframe(%Timeframe.StartingLaterToday{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    test "time range - start of service to end" do
      assert " from start of service to end of service" ==
               FormattedAlert.summary_timeframe(%Timeframe.TimeRange{
                 start_time: %StartOfService{},
                 end_time: %EndOfService{}
               })
    end

    # TODO: time formatting
    @tag :skip
    test "time range - time to time" do
      assert " from 10:31 AM to 2:31 PM" ==
               FormattedAlert.summary_timeframe(%Timeframe.TimeRange{
                 start_time: ~B[2026-04-29 10:31:00],
                 end_time: ~B[2026-04-29 14:31:00]
               })
    end
  end

  describe "summary_recurrence/1" do
    test "daily until further notice" do
      assert "daily until further notice" =
               FormattedAlert.summary_recurrence(%Recurrence.Daily{
                 ending: %Timeframe.UntilFurtherNotice{}
               })
    end

    # TODO: Unskip w/ time formatting
    @tag :skip
    test "some days until later date" do
      assert "some days through Apr 29" =
               FormattedAlert.summary_recurrence(%Recurrence.SomeDays{
                 ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}
               })
    end

    # TODO: Unskip w/ time formatting
    @tag :skip
    test "some days through this week" do
      assert "some days through Wednesday" =
               FormattedAlert.summary_recurrence(%Recurrence.SomeDays{
                 ending: %Timeframe.ThisWeek{time: ~B[2026-04-29 10:31:00]}
               })
    end
  end

  describe "summary_trip_identity/1" do
    # TODO: Unskip w/ time formatting
    @tag :skip
    test "trip from" do
      assert "**10:31** from **Oak Grove**" =
               FormattedAlert.summary_trip_identity(%TripSpecific.TripFrom{
                 trip_time: ~B[2026-04-29 10:31:00],
                 route_type: :commuter_rail,
                 stop_name: "Oak Grove"
               })
    end

    # TODO: Unskip w/ time formatting
    @tag :skip

    test "trip to" do
      assert "**10:31** to **North Station**" =
               FormattedAlert.summary_trip_identity(%TripSpecific.TripTo{
                 trip_time: ~B[2026-04-29 10:31:00],
                 route_type: :commuter_rail,
                 headsign: "North Station"
               })
    end

    test "mutiple trips" do
      assert "Multiple trips" =
               FormattedAlert.summary_trip_identity(%TripSpecific.MultipleTrips{})
    end
  end

  describe "summary_trip_shuttle_identity/1" do
    # TODO: Unskip w/ time formatting
    @tag :skip
    test "one trip" do
      assert "the **10:30** train" ==
               FormattedAlert.summary_trip_shuttle_identity(%TripShuttle.SingleTrip{
                 trip_time: ~B[2026-04-29 10:31:00],
                 route_type: :commuter_rail,
                 from_stop_name: "Oak Grove"
               })
    end

    test "multiple trips" do
      assert "multiple trips" ==
               FormattedAlert.summary_trip_shuttle_identity(%TripShuttle.MultipleTrips{})
    end
  end

  describe "summary_trip_effect/4" do
    test "multiple cancelled" do
      summary =
        FormattedAlert.summary_trip_effect(
          %TripSpecific.MultipleTrips{},
          :cancellation,
          nil,
          true
        )

      assert "are cancelled today" == summary
    end

    test "one cancelled" do
      summary =
        FormattedAlert.summary_trip_effect(
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
        FormattedAlert.summary_trip_effect(
          %TripSpecific.TripFrom{
            trip_time: ~B[2026-04-29 10:31:00],
            route_type: :commuter_rail,
            stop_name: "Oak Grove"
          },
          :station_closure,
          ["A", "B", "C"],
          false
        )

      assert "will not stop at **A** and **B** and **C** tomorrow" == summary
    end

    test "one stop closed" do
      summary =
        FormattedAlert.summary_trip_effect(
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
        FormattedAlert.summary_trip_effect(
          %TripSpecific.MultipleTrips{},
          :suspension,
          nil,
          true
        )

      assert "are suspended today" == summary
    end

    test "one suspended" do
      summary =
        FormattedAlert.summary_trip_effect(
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
        FormattedAlert.summary_trip_effect(
          %TripSpecific.TripFrom{
            trip_time: ~B[2026-04-29 10:31:00],
            route_type: :commuter_rail,
            stop_name: "Oak Grove"
          },
          :modified_service,
          nil,
          true
        )

      # TODO: this should probably be lower case
      assert "affected by modified service today" == summary
    end
  end
end

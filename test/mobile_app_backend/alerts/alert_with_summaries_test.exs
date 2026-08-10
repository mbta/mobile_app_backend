defmodule MobileAppBackend.Alerts.AlertWithSummariesTest do
  use ExUnit.Case, async: true

  import MobileAppBackend.Factory
  import Test.Support.Sigils

  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertWithSummaries
  alias MobileAppBackend.Alerts.SummaryEntity

  describe "should_recalculate_summaries?/3" do
    test "returns true when alert content has changed" do
      old_alert = build(:alert, id: "a_1")

      old_with_summary =
        AlertWithSummaries.from_alert(old_alert, [%SummaryEntity{summary: "asdf"}])

      new_alert = %{old_alert | informed_entity: [%Alert.InformedEntity{route: "Red"}]}

      assert AlertWithSummaries.should_recalculate_summaries?(
               old_with_summary,
               new_alert,
               DateTime.now!("America/New_York")
             )
    end

    test "returns true when active status has changed" do
      now = DateTime.now!("America/New_York")

      old_alert =
        build(:alert,
          id: "a_1",
          active_period: [
            %Alert.ActivePeriod{
              start: DateTime.add(now, 1, :hour),
              end: DateTime.add(now, 3, :hour)
            }
          ]
        )

      old_with_summary =
        AlertWithSummaries.from_alert(old_alert, [%SummaryEntity{summary: "asdf"}], now)

      assert AlertWithSummaries.should_recalculate_summaries?(
               old_with_summary,
               old_alert,
               DateTime.add(now, 2, :hour)
             )
    end

    test "returns true when calendar date has changed" do
      now = DateTime.now!("America/New_York")

      old_alert =
        build(:alert,
          id: "a_1"
        )

      old_with_summary =
        AlertWithSummaries.from_alert(old_alert, [%SummaryEntity{summary: "asdf"}], now)

      assert AlertWithSummaries.should_recalculate_summaries?(
               old_with_summary,
               old_alert,
               DateTime.add(now, 1, :day)
             )
    end

    test "returns true when GTFS service date has changed" do
      now = ~B[2026-08-05 01:01:01]

      old_alert =
        build(:alert,
          id: "a_1"
        )

      old_with_summary =
        AlertWithSummaries.from_alert(old_alert, [%SummaryEntity{summary: "asdf"}], now)

      assert AlertWithSummaries.should_recalculate_summaries?(
               old_with_summary,
               old_alert,
               ~B[2026-08-05 06:01:01]
             )
    end

    test "returns false when alert, active state, and dates are unchanged" do
      now = ~B[2026-08-05 06:01:01]

      old_alert =
        build(:alert,
          id: "a_1"
        )

      old_with_summary =
        AlertWithSummaries.from_alert(old_alert, [%SummaryEntity{summary: "asdf"}], now)

      refute AlertWithSummaries.should_recalculate_summaries?(
               old_with_summary,
               old_alert,
               ~B[2026-08-05 07:01:01]
             )
    end
  end
end

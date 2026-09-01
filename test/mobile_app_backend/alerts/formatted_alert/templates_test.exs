defmodule MobileAppBackend.Alerts.FormattedAlert.TemplatesTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory

  alias MobileAppBackend.Alerts.FormattedAlert.Templates

  describe "standard/5" do
    test "dock_closure" do
      summary =
        Templates.standard(
          build(:alert, effect: :dock_closure),
          "**A**",
          " until further notice",
          "",
          :notification
        )

      assert "Ferries will not stop at **A** until further notice" == summary
    end

    test "delay" do
      summary =
        Templates.standard(
          build(:alert, effect: :delay, severity: 3),
          "",
          " until further notice",
          "",
          :notification
        )

      assert "**Delays** of about 10 minutes until further notice" == summary
    end

    test "fallback" do
      summary =
        Templates.standard(
          build(:alert, effect: :detour),
          "",
          " until further notice",
          "",
          :card
        )

      assert "**Detour** until further notice" == summary
    end

    test "fallback cause when missing location" do
      summary =
        Templates.standard(
          build(:alert, effect: :detour, cause: :maintenance),
          "",
          " until further notice",
          "",
          :card
        )

      assert "**Detour** until further notice due to maintenance" == summary
    end

    test "fallback cause when unknown end time" do
      summary =
        Templates.standard(
          build(:alert, effect: :detour, cause: :maintenance),
          " from X to Y",
          " until further notice",
          "",
          :card
        )

      assert "**Detour** from X to Y until further notice due to maintenance" == summary
    end

    test "fallback no cause when location and timeframe" do
      summary =
        Templates.standard(
          build(:alert, effect: :detour, cause: :maintenance),
          " from X to Y",
          " starting at 4PM",
          "",
          :card
        )

      assert "**Detour** from X to Y starting at 4PM" == summary
    end

    test "detour notification see alert details" do
      summary =
        Templates.standard(
          build(:alert, effect: :detour, cause: :maintenance),
          " from X to Y",
          " until further notice",
          "",
          :notification
        )

      assert "**Detour** from X to Y until further notice due to maintenance. See alert details." ==
               summary
    end

    test "Elevator closure" do
      summary =
        Templates.standard(
          build(:alert, effect: :elevator_closure, cause: :maintenance),
          " at Porter",
          " until further notice",
          "",
          :notification
        )

      assert "**Elevator closed** at Porter until further notice due to maintenance" == summary
    end
  end

  describe "all_clear/3" do
    test "station_closure" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :station_closure),
          true,
          " at **Wood Island**"
        )

      assert "**Update:** Train service has resumed at **Wood Island**." == summary
    end

    test "delay" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :delay),
          true,
          " at **Wood Island**"
        )

      assert "**Update:** Delay has ended at **Wood Island**." == summary
    end

    test "with no location" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          true,
          ""
        )

      assert "**Update:** Detour has ended." == summary
    end

    test "returns normal service resumed when single all clear" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          false,
          " at **Wood Island**"
        )

      assert "**All clear:** Normal service has resumed." == summary
    end
  end

  describe "trip_specific/6" do
    test "multiple cancelled" do
      summary =
        Templates.trip_specific(
          "These trips",
          build(:alert, effect: :cancellation, cause: :weather),
          nil,
          "today",
          "",
          true
        )

      assert "These trips are cancelled today due to weather" == summary
    end

    test "one cancelled" do
      summary =
        Templates.trip_specific(
          "This trip",
          build(:alert, effect: :cancellation, cause: :weather),
          nil,
          "tomorrow",
          "",
          false
        )

      assert "This trip is cancelled tomorrow due to weather" == summary
    end

    test "multiple stops closed" do
      summary =
        Templates.trip_specific(
          "10:31 train from Oak Grove",
          build(:alert, effect: :station_closure, cause: :weather),
          ["A", "B", "C"],
          "tomorrow",
          "",
          false
        )

      assert "10:31 train from Oak Grove will not stop at **A**, **B**, and **C** tomorrow due to weather" ==
               summary
    end

    test "one stop closed" do
      summary =
        Templates.trip_specific(
          "10:31 train from Oak Grove",
          build(:alert, effect: :station_closure, cause: :weather),
          ["A"],
          "tomorrow",
          "",
          false
        )

      assert "10:31 train from Oak Grove will not stop at **A** tomorrow due to weather" ==
               summary
    end

    test "suspension with terminating stop" do
      summary =
        Templates.trip_specific(
          "This trip",
          build(:alert, effect: :suspension, cause: :weather),
          ["A", "B"],
          "today",
          "",
          false
        )

      assert "This trip will terminate at A today due to weather" == summary
    end

    test "multiple suspended" do
      summary =
        Templates.trip_specific(
          "Multiple trips",
          build(:alert, effect: :suspension, cause: :weather),
          nil,
          "today",
          "",
          true
        )

      assert "Multiple trips are suspended today due to weather" == summary
    end

    test "one suspended" do
      summary =
        Templates.trip_specific(
          "This trip",
          build(:alert, effect: :suspension, cause: :weather),
          nil,
          "today",
          "",
          false
        )

      assert "This trip is suspended today due to weather" == summary
    end

    test "delays" do
      summary =
        Templates.trip_specific(
          "This trip",
          build(:alert, effect: :delay, cause: :weather, severity: 3),
          nil,
          "today",
          "",
          false
        )

      assert "This trip experiencing delays of about 10 minutes today due to weather" == summary
    end

    test "fallback" do
      summary =
        Templates.trip_specific(
          "This trip",
          build(:alert, effect: :modified_service, cause: :weather),
          nil,
          "today",
          "",
          false
        )

      assert "This trip affected by Modified service today due to weather" == summary
    end
  end
end

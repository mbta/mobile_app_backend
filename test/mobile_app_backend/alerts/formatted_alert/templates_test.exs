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
          false
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
          false
        )

      assert "**Delays** of about 10 minutes until further notice" == summary
    end

    test "fallback update" do
      summary =
        Templates.standard(
          build(:alert, effect: :detour),
          "",
          " until further notice",
          "",
          true
        )

      assert "**Update:** Detour until further notice" == summary
    end

    test "fallback" do
      summary =
        Templates.standard(
          build(:alert, effect: :detour),
          "",
          " until further notice",
          "",
          false
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
          false
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
          false
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
          false
        )

      assert "**Detour** from X to Y starting at 4PM" == summary
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

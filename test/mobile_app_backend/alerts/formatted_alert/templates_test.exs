defmodule MobileAppBackend.Alerts.FormattedAlert.TemplatesTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory

  alias MobileAppBackend.Alerts.FormattedAlert.Templates

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

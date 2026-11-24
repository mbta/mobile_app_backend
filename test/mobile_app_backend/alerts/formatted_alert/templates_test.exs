defmodule MobileAppBackend.Alerts.FormattedAlert.TemplatesTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory

  alias MobileAppBackend.Alerts.AlertSummary.Location
  alias MobileAppBackend.Alerts.AlertSummary.OtherActiveAlert
  alias MobileAppBackend.Alerts.FormattedAlert.Templates

  @other_detour [%OtherActiveAlert{effect: :detour}]

  describe "standard/5" do
    test "dock_closure" do
      summary =
        Templates.standard(
          build(:alert, effect: :dock_closure),
          " at **A**",
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
          "",
          "",
          :notification
        )

      assert "**Delays** of about 10 minutes" == summary
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
          @other_detour,
          " at **Wood Island**"
        )

      assert "**Update:** Train service has resumed at **Wood Island**. Detour is still in effect." ==
               summary
    end

    test "delay" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :delay),
          @other_detour,
          " at **Wood Island**"
        )

      assert "**Update:** Delays have ended at **Wood Island**. Detour is still in effect." ==
               summary
    end

    test "track_change" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :track_change),
          @other_detour,
          " at **Wood Island**"
        )

      assert "**Update:** Track change has ended at **Wood Island**. Detour is still in effect." ==
               summary
    end

    test "shuttle" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :shuttle, informed_entity: [%{route_type: :bus}]),
          @other_detour,
          " at **Wood Island**"
        )

      assert "**Update:** Bus service has resumed at **Wood Island**. Detour is still in effect." ==
               summary
    end

    test "with no location" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          @other_detour,
          ""
        )

      assert "**Update:** Detour has ended. Detour is still in effect." == summary
    end

    test "elevator_closure" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :elevator_closure),
          @other_detour,
          " at **Wood Island**"
        )

      assert "**Update:** Elevator service has resumed at **Wood Island**. Detour is still in effect." ==
               summary
    end

    test "uses the closure noun for another closure still in effect" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          [%OtherActiveAlert{effect: :stop_closure}],
          ""
        )

      assert "**Update:** Detour has ended. Stop closure is still in effect." == summary
    end

    test "uses the suspension noun for another suspension still in effect" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          [%OtherActiveAlert{effect: :suspension}],
          ""
        )

      assert "**Update:** Detour has ended. Suspension is still in effect." == summary
    end

    test "is generic when several other alerts are still in effect" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :suspension),
          [%OtherActiveAlert{effect: :detour}, %OtherActiveAlert{effect: :delay}],
          " at **Wood Island**"
        )

      assert "**Update:** Suspension has ended at **Wood Island**. Other disruptions are still in effect." ==
               summary
    end

    test "includes the location of another shuttle with different start and end stops" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :shuttle, informed_entity: [%{route_type: :bus}]),
          [
            %OtherActiveAlert{
              effect: :shuttle,
              location: %Location.SuccessiveStops{
                start_stop_name: "Kenmore",
                end_stop_name: "Copley"
              }
            }
          ],
          " from **Riverside** to **Newton Highlands**"
        )

      assert "**Update:** Bus service has resumed from **Riverside** to **Newton Highlands**. Shuttle buses are still in effect from **Kenmore** to **Copley**." ==
               summary
    end

    test "includes the whole route of another shuttle" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :shuttle, informed_entity: [%{route_type: :bus}]),
          [
            %OtherActiveAlert{
              effect: :shuttle,
              location: %Location.WholeRoute{route_label: "Green Line B", route_type: :light_rail}
            }
          ],
          ""
        )

      assert "**Update:** Bus service has resumed. Shuttle buses are still in effect replacing **Green Line B**." ==
               summary
    end

    test "includes the location of another station closure" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :station_closure),
          [
            %OtherActiveAlert{
              effect: :station_closure,
              location: %Location.AffectedStops{stops: ["Malden Center", "Oak Grove"]}
            }
          ],
          " at **Wood Island**"
        )

      assert "**Update:** Train service has resumed at **Wood Island**. Station closure is still in effect at **Malden Center** and **Oak Grove**." ==
               summary
    end

    test "includes the location of another suspension" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :suspension),
          [
            %OtherActiveAlert{
              effect: :suspension,
              location: %Location.SuccessiveStops{
                start_stop_name: "Alewife",
                end_stop_name: "Harvard"
              }
            }
          ],
          " from **Oak Grove** to **North Station**"
        )

      assert "**Update:** Suspension has ended from **Oak Grove** to **North Station**. Suspension is still in effect from **Alewife** to **Harvard**." ==
               summary
    end

    test "includes the location of other delays" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :delay),
          [
            %OtherActiveAlert{
              effect: :delay,
              location: %Location.SingleStop{stop_name: "Ruggles"}
            }
          ],
          " at **Wood Island**"
        )

      assert "**Update:** Delays have ended at **Wood Island**. Delays are still in effect at **Ruggles**." ==
               summary
    end

    test "has no location for another alert with the same effect when it has none" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          [%OtherActiveAlert{effect: :detour, location: nil}],
          " at **Wood Island**"
        )

      assert "**Update:** Detour has ended at **Wood Island**. Detour is still in effect." ==
               summary
    end

    test "omits the location of another alert with a different effect" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          [
            %OtherActiveAlert{
              effect: :shuttle,
              location: %Location.SuccessiveStops{
                start_stop_name: "Kenmore",
                end_stop_name: "Copley"
              }
            }
          ],
          " at **Wood Island**"
        )

      assert "**Update:** Detour has ended at **Wood Island**. Shuttle buses are still in effect." ==
               summary
    end

    test "returns normal service resumed when single all clear" do
      summary =
        Templates.all_clear(
          build(:alert, effect: :detour),
          [],
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

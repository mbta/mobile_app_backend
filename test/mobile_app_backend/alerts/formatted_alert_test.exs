defmodule MobileAppBackend.Alerts.FormattedAlertTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory
  import Test.Support.Sigils
  alias MobileAppBackend.Alerts.AlertSummary

  alias MobileAppBackend.Alerts.AlertSummary.{
    Location,
    Recurrence,
    Timeframe,
    TripShuttle,
    TripSpecific,
    Unknown
  }

  alias MobileAppBackend.Alerts.FormattedAlert

  describe "summary/2 all_clear" do
    test "all clear with single active alert" do
      alert = build(:alert, effect: :detour)

      alert_summary = %AlertSummary.AllClear{
        location: %Location.SuccessiveStops{
          start_stop_name: "Oak Grove",
          end_stop_name: "North Station",
          downstream: false
        },
        has_multiple_active_alerts: false,
        effect: alert.effect
      }

      assert "All clear: Normal service has resumed." ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "all clear whole route" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.AllClear{
        location: %Location.WholeRoute{route_type: :heavy_rail, route_label: "Red Line"},
        has_multiple_active_alerts: true,
        effect: alert.effect
      }

      assert "Update: Suspension has ended on Red Line." ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "all clear successive stops" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.AllClear{
        location: %Location.SuccessiveStops{
          start_stop_name: "Oak Grove",
          end_stop_name: "North Station",
          downstream: false
        },
        has_multiple_active_alerts: true,
        effect: alert.effect
      }

      assert "Update: Suspension has ended from Oak Grove to North Station." ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "all clear single stop" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.AllClear{
        location: %Location.SingleStop{
          stop_name: "Ruggles",
          downstream: false
        },
        has_multiple_active_alerts: true,
        effect: alert.effect
      }

      assert "Update: Suspension has ended at Ruggles." ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "all clear station closure" do
      alert = build(:alert, effect: :station_closure)

      alert_summary = %AlertSummary.AllClear{
        location: %Location.SingleStop{
          stop_name: "Oak Grove",
          downstream: false
        },
        has_multiple_active_alerts: true,
        effect: alert.effect
      }

      assert "Update: Train service has resumed at Oak Grove." ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end
  end

  describe "summary/2 standard" do
    test "daily shuttle between stops until further notice" do
      alert = build(:alert, effect: :shuttle)

      alert_summary = %AlertSummary.Standard{
        location: %Location.SuccessiveStops{
          start_stop_name: "Oak Grove",
          end_stop_name: "North Station",
          downstream: false
        },
        timeframe: %Timeframe.UntilFurtherNotice{},
        recurrence: %Recurrence.Daily{}
      }

      assert "Shuttle buses from Oak Grove to North Station until further notice" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "station bypass until further notice" do
      alert = build(:alert, effect: :station_closure)

      alert_summary = %AlertSummary.Standard{
        effect: :station_closure,
        location: %Location.AffectedStops{
          stops: ["Oak Grove", "North Station"]
        },
        timeframe: %Timeframe.UntilFurtherNotice{},
        recurrence: %Recurrence.Daily{}
      }

      assert "Trains will not stop at Oak Grove and North Station until further notice" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "stop bypass until further notice" do
      alert = build(:alert, effect: :stop_closure)

      alert_summary = %AlertSummary.Standard{
        effect: :stop_closure,
        location: %Location.AffectedStops{
          stops: ["Back Bay", "Ruggles"]
        },
        timeframe: %Timeframe.UntilFurtherNotice{},
        recurrence: %Recurrence.Daily{}
      }

      assert "Buses will not stop at Back Bay and Ruggles until further notice" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end
  end

  describe "summary/2 trip-specific" do
    test "suspension" do
      alert = build(:alert, effect: :suspension, cause: :accident)

      alert_summary = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{
          trip_time: ~B[2026-04-29 10:31:00],
          route_type: :commuter_rail,
          stop_name: "North Station"
        },
        effect: :suspension,
        effect_stops: [],
        is_today: true,
        cause: :accident,
        recurrence: %Recurrence.Daily{ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}}
      }

      assert "10:31 AM train from North Station is suspended today due to accident daily until Apr 29" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "downstream suspension" do
      alert = build(:alert, effect: :suspension, cause: :weather)

      alert_summary = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.TripFrom{
          trip_time: ~B[2026-04-29 10:31:00],
          route_type: :commuter_rail,
          stop_name: "Concord"
        },
        effect: :suspension,
        effect_stops: ["Porter"],
        is_today: true,
        cause: :weather,
        recurrence: nil
      }

      assert "10:31 AM train from Concord will terminate at Porter today due to weather" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "this trip suspension" do
      alert = build(:alert, effect: :suspension, cause: :weather)

      alert_summary = %AlertSummary.TripSpecific{
        trip_identity: %TripSpecific.ThisTrip{
          route_type: :commuter_rail
        },
        effect: :suspension,
        effect_stops: nil,
        is_today: true,
        cause: :weather,
        recurrence: nil
      }

      assert "This train is suspended today due to weather" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end
  end

  describe "summary/2 trip-shuttle" do
    test "single trip shuttle" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{
          trip_time: ~B[2026-04-29 10:31:00],
          route_type: :commuter_rail,
          from_stop_name: "North Station"
        },
        start_stop_name: "North Station",
        end_stop_name: "Oak Grove",
        recurrence: %Recurrence.SomeDays{
          ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}
        }
      }

      assert "10:31 AM train from North Station is replaced by shuttle buses from North Station to Oak Grove some days until Apr 29" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "single trip shuttle nil from stop " do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{
          trip_time: ~B[2026-04-29 10:31:00],
          route_type: :commuter_rail,
          from_stop_name: nil
        },
        start_stop_name: "North Station",
        end_stop_name: "Oak Grove",
        recurrence: %Recurrence.SomeDays{
          ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}
        }
      }

      assert "Shuttle buses replace the 10:31 AM train from North Station to Oak Grove some days until Apr 29" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "downstream shuttle" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.SingleTrip{
          trip_time: ~B[2026-04-29 10:31:00],
          route_type: :commuter_rail,
          from_stop_name: "Concord"
        },
        start_stop_name: "Porter",
        end_stop_name: "North Station",
        recurrence: nil
      }

      assert "10:31 AM train from Concord is replaced by shuttle buses from Porter to North Station" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "this trip shuttle" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.ThisTrip{
          route_type: :commuter_rail
        },
        start_stop_name: "Porter",
        end_stop_name: "North Station",
        recurrence: nil
      }

      assert "Shuttle buses replace this train from Porter to North Station" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "multiple trip shuttle" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.TripShuttle{
        trip_identity: %TripShuttle.MultipleTrips{},
        start_stop_name: "North Station",
        end_stop_name: "Oak Grove",
        recurrence: %Recurrence.Daily{
          ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}
        }
      }

      assert "Shuttle buses replace multiple trips from North Station to Oak Grove daily until Apr 29" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end
  end

  describe "summary/2 unknown" do
    test "fallback" do
      assert "test" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert_summary: %Unknown{fallback: "test"}},
                 "en"
               )
    end
  end

  describe "summary_trip_identity/1" do
    test "trip from" do
      assert "**10:31 AM** train from **Oak Grove**" =
               FormattedAlert.summary_trip_identity(%TripSpecific.TripFrom{
                 trip_time: ~B[2026-04-29 10:31:00],
                 route_type: :commuter_rail,
                 stop_name: "Oak Grove"
               })
    end

    test "trip to" do
      assert "**10:31 AM** train to **North Station**" =
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
    test "one trip" do
      assert "**10:31 AM** train from **Oak Grove**" ==
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

  describe "summary standard stops skipped" do
    test "one stops skipped" do
      alert = build(:alert, effect: :stop_closure)

      alert_summary = %AlertSummary.Standard{
        effect: :stop_closure,
        location: %Location.AffectedStops{
          stops: ["Back Bay"]
        },
        timeframe: %Timeframe.UntilFurtherNotice{}
      }

      assert "Buses will not stop at Back Bay until further notice" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "two stops skipped" do
      alert = build(:alert, effect: :stop_closure)

      alert_summary = %AlertSummary.Standard{
        effect: :stop_closure,
        location: %Location.AffectedStops{
          stops: ["Back Bay", "Ruggles"]
        },
        timeframe: %Timeframe.UntilFurtherNotice{}
      }

      assert "Buses will not stop at Back Bay and Ruggles until further notice" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "three stops skipped" do
      alert = build(:alert, effect: :stop_closure)

      alert_summary = %AlertSummary.Standard{
        effect: :stop_closure,
        location: %Location.AffectedStops{
          stops: ["Back Bay", "Ruggles", "Hyde Park"]
        },
        timeframe: %Timeframe.UntilFurtherNotice{}
      }

      assert "Buses will not stop at Back Bay, Ruggles, and Hyde Park until further notice" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end

    test "multiple stops skipped" do
      alert = build(:alert, effect: :stop_closure)

      alert_summary = %AlertSummary.Standard{
        effect: :stop_closure,
        location: %Location.AffectedStops{
          stops: ["Back Bay", "Ruggles", "Hyde Park", "Readville"]
        },
        timeframe: %Timeframe.UntilFurtherNotice{}
      }

      assert "Buses will not stop at multiple stops until further notice" ==
               FormattedAlert.summary(
                 %FormattedAlert{alert: alert, alert_summary: alert_summary},
                 "en"
               )
    end
  end

  test "one stops skipped upcoming" do
    alert = build(:alert, effect: :dock_closure)

    alert_summary = %AlertSummary.Standard{
      effect: :dock_closure,
      location: %Location.AffectedStops{
        stops: ["Long Wharf"]
      },
      timeframe: %Timeframe.StartingTomorrow{}
    }

    assert "Ferries will not stop at Long Wharf starting tomorrow" ==
             FormattedAlert.summary(
               %FormattedAlert{alert: alert, alert_summary: alert_summary},
               "en"
             )
  end
end

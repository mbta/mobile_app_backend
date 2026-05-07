defmodule MobileAppBackend.Alerts.FormattedAlertTest do
  use ExUnit.Case, async: true
  import MobileAppBackend.Factory
  import Test.Support.Sigils
  require Jason.Sigil
  alias MobileAppBackend.Alerts.AlertSummary

  alias MobileAppBackend.Alerts.AlertSummary.{
    Direction,
    Location,
    Recurrence,
    Timeframe,
    TripShuttle,
    TripSpecific,
    Unknown
  }

  alias MobileAppBackend.Alerts.AlertSummary.Timeframe.TimeRange.{EndOfService, StartOfService}
  alias MobileAppBackend.Alerts.FormattedAlert

  describe "summary/2 all_clear" do
    test "all clear whole route" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.AllClear{
        location: %Location.WholeRoute{route_type: :heavy_rail, route_label: "Red Line"}
      }

      assert "All clear: Regular service on Red Line" ==
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
        }
      }

      assert "All clear: Regular service from Oak Grove to North Station" ==
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
        }
      }

      assert "All clear: Regular service at Ruggles" ==
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

    test "update" do
      alert = build(:alert, effect: :suspension)

      alert_summary = %AlertSummary.Standard{
        location: %Location.SuccessiveStops{
          start_stop_name: "Oak Grove",
          end_stop_name: "North Station",
          downstream: false
        },
        recurrence: %Recurrence.Daily{ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}},
        is_update: true
      }

      assert "Update: Service suspended from Oak Grove to North Station daily until Apr 29" ==
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
      alert = build(:alert, effect: :suspension)

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
      alert = build(:alert, effect: :suspension)

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
      alert = build(:alert, effect: :suspension)

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

  describe "summary_location/2" do
    test "direction to stop" do
      assert " from **Northbound** stops to **Downtown Crossing**" ==
               FormattedAlert.summary_location(:suspension, %Location.DirectionToStop{
                 direction: %Direction{name: "North", destination: "Oak Grove"},
                 end_stop_name: "Downtown Crossing"
               })
    end

    test "single stop" do
      assert " at **Downtown Crossing**" ==
               FormattedAlert.summary_location(:suspension, %Location.SingleStop{
                 stop_name: "Downtown Crossing",
                 downstream: false
               })
    end

    test "stop to direction" do
      assert " from **Downtown Crossing** to **Northbound** stops" ==
               FormattedAlert.summary_location(:suspension, %Location.StopToDirection{
                 direction: %Direction{name: "North", destination: "Oak Grove"},
                 start_stop_name: "Downtown Crossing"
               })
    end

    test "successive stops" do
      assert " from **Downtown Crossing** to **Oak Grove**" ==
               FormattedAlert.summary_location(:suspension, %Location.SuccessiveStops{
                 start_stop_name: "Downtown Crossing",
                 end_stop_name: "Oak Grove"
               })
    end

    test "whole route shuttle" do
      assert " replacing **Red Line**" ==
               FormattedAlert.summary_location(:shuttle, %Location.WholeRoute{
                 route_label: "Red Line",
                 route_type: :heavy_rail
               })
    end

    test "whole route other" do
      assert " on **Red Line**" ==
               FormattedAlert.summary_location(:suspension, %Location.WholeRoute{
                 route_label: "Red Line",
                 route_type: :heavy_rail
               })
    end

    test "whole route bus" do
      assert " on **132 bus**" ==
               FormattedAlert.summary_location(:suspension, %Location.WholeRoute{
                 route_label: "132",
                 route_type: :bus
               })
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

    test "later date" do
      assert " through Apr 29" ==
               FormattedAlert.summary_timeframe(%Timeframe.LaterDate{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    test "this week" do
      assert " through Wednesday" ==
               FormattedAlert.summary_timeframe(%Timeframe.ThisWeek{
                 time: ~B[2026-04-29 10:31:00]
               })
    end

    test "time" do
      assert " through 10:31 AM" ==
               FormattedAlert.summary_timeframe(%Timeframe.Time{time: ~B[2026-04-29 10:31:00]})
    end

    test "starting tomorrow" do
      assert " starting tomorrow" ==
               FormattedAlert.summary_timeframe(%Timeframe.StartingTomorrow{})
    end

    test "starting later today" do
      assert " starting **10:31 AM** today" ==
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

    test "time range - time to time" do
      assert " from 10:31 AM to 2:31 PM" ==
               FormattedAlert.summary_timeframe(%Timeframe.TimeRange{
                 start_time: %Timeframe.TimeRange.Time{time: ~B[2026-04-29 10:31:00]},
                 end_time: %Timeframe.TimeRange.Time{time: ~B[2026-04-29 14:31:00]}
               })
    end
  end

  describe "summary_recurrence/1" do
    test "daily until further notice" do
      assert " daily until further notice" =
               FormattedAlert.summary_recurrence(%Recurrence.Daily{
                 ending: %Timeframe.UntilFurtherNotice{}
               })
    end

    test "some days until later date" do
      assert " some days until Apr 29" =
               FormattedAlert.summary_recurrence(%Recurrence.SomeDays{
                 ending: %Timeframe.LaterDate{time: ~B[2026-04-29 10:31:00]}
               })
    end

    test "some days through this week" do
      assert " some days until Wednesday" =
               FormattedAlert.summary_recurrence(%Recurrence.SomeDays{
                 ending: %Timeframe.ThisWeek{time: ~B[2026-04-29 10:31:00]}
               })
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

      assert "will not stop at **A**, **B**, and **C** tomorrow" == summary
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

      assert "affected by Modified service today" == summary
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
end

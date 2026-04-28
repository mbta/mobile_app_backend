defmodule MobileAppBackend.Alerts.FormattedAlert do
  use Gettext, backend: MobileAppBackend.Gettext
  alias MBTAV3API.Alert
alias MobileAppBackend.Alerts.AlertSummary

      @type t :: %__MODULE__{
            alert: Alert.t() | nil,
            alert_summary: AlertSummary.t()
          }
    @derive PolymorphicJson
    defstruct [:trip_time, :route_type, :from_stop_name]



  @spec summary(AlertSummary.t() | nil, ) :: String.t() | nil
  def summary(alert_summary, locale) do
         case alert_summary do
        %AlertSummary.AllClear{} ->
          gettext("**All clear:** Regular service%{location}" , location: summary_location(nil, location: alert_summary.location))

                %AlertSummary.Summary{} ->
                  sentence_case_effect = "TODO"
                  summary_location = summary_location(alert_summary.effect, alert_summary.location)
                  summary_timeframe = summary_timeframe(alert_summary.timeframe)
                  summary_recurrence = summary_recurrence(alert_summary.recurrence)

                  if (alert_summary.is_update) do
                    gettext("**Update:** %{sentence_case_effect}%{summary_location}%{summary_timeframe}%{summary_recurrence}", sentence_case_effect: sentence_case_effect, summary_location: summary_location, summary_timeframe: summary_timeframe, summary_recurrence: summary_recurrence)
                  else
                    gettext("**%{sentence_case_effect}**%{summary_location}%{summary_timeframe}%{summary_recurrence}", sentence_case_effect: sentence_case_effect, summary_location: summary_location, summary_timeframe: summary_timeframe, summary_recurrence: summary_recurrence)
                  end


        case let .tripSpecificAlertSummary(alertSummary): return AttributedString.tryMarkdown(String(
                format: NSLocalizedString(
                    "%1$@ %2$@%3$@%4$@",
                    comment: """
                    Alert summary in the format of “[trip identity] [is affected][due to cause][until recurrence]”, \
                    ex “[12:13 PM from Ruggles] [is cancelled today][ due to a mechanical issue][ \
                    some days until Wednesday]” or “[Multiple trips] [are suspended today][][]”
                    """
                ),
                Self.summaryTripIdentity(tripIdentity: alertSummary.tripIdentity),
                Self.summaryTripEffect(
                    tripIdentity: alertSummary.tripIdentity,
                    effect: alertSummary.effect,
                    effectStops: alertSummary.effectStops,
                    isToday: alertSummary.isToday
                ),
                summaryTripCause,
                Self.summaryRecurrence(recurrence: alertSummary.recurrence)
            ))
        case let .tripShuttleAlertSummary(alertSummary): return AttributedString.tryMarkdown(String(
                format: NSLocalizedString(
                    "Shuttle buses replace %1$@ %2$@ from **%3$@** to **%4$@**%5$@",
                    comment: """
                    Alert summary in the format of “Shuttle buses replace [trip identity] [day] \
                    from [stop] to [stop][until recurrence]”, ex “Shuttle buses replace [the 12:13 PM train] \
                    [today] from [Ruggles] to [Forest Hills][ some days until Friday]”
                    """
                ),
                Self.summaryTripShuttleIdentity(tripIdentity: alertSummary.tripIdentity),
                alertSummary.isToday ? NSLocalizedString("today", comment: "") : NSLocalizedString(
                    "tomorrow",
                    comment: ""
                ),
                alertSummary.currentStopName,
                alertSummary.endStopName,
                Self.summaryRecurrence(recurrence: alertSummary.recurrence)
            ))
        case let .unknown(alertSummary): return AttributedString(alertSummary.fallback)
        case nil: return nil


  end

  @spec summary_location(Alert.Effect.t() | nil, AlertSummary.Location.t() | nil) :: String.t()
    def summary_location(effect, location) do
        case location do
          %AlertSummary.Location.DirectionToStop{} ->

          gettext(" from **%{direction_name}** stops to **%{end_stop_name}**",
          direction_name: DirectionLabel.direction_name_formatted(location.direction), end_stop_name: location.end_stop_name)

        %AlertSummary.Location.SingleStop{} ->

          gettext(" at **%{stop_name}**", stop_name: location.stop_name)

        %AlertSummary.StopToDirection{} ->
          gettext(" from **%{stop_name}** to **%{direction_name}** stops", stop_name: location.start_stop_name, direction_name: DirectionLabel.direction_name_formatted(location.direction))

        %AlertSummary.SuccessiveStops{} ->
            gettext(" from **%{start_stop}** to **%{end_stop}**", start_stop: location.start_stop_name, end_stop: location.end_stop_name),


        %AlertSummary.WholeRoute{} ->
            if effect == :shuttle do
              gettext(" replacing **%{mode_label}**", mode_label: AlertSummary.WholeRoute.mode_label(location))
            else
              gettext(" on **%{mode_label}**", mode_label: AlertSummary.WholeRoute.mode_label(location))
            end


        case AlertSummary.Unknown ->  ""

         nil ->  ""

          end
        end

          @spec summary_timeframe(AlertSummary.Timeframe.t() | nil) :: String.t()
          def summary_timeframe(timeframe) do
             static func summaryTimeframe(timeframe: AlertSummary.Timeframe?) -> String {
        case timeframe do
         %AlertSummary.Timeframe.UntilFurtherNotice{} ->
          gettext(" until further notice")
         %AlertSummary.Timeframe.EndOfService{} ->
            gettext(" through end of service")
         %AlertSummary.Timeframe.Tomorrow{} -> gettext(" through tomorrow")
         %AlertSummary.Timeframe.LaterDate{} ->
          ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##     .formatted(.init().month(.abbreviated).day()))
          gettext(" through %{formatted_date}", formatted_date: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards))

         %AlertSummary.Timeframe.ThisWeek{} ->
                    ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##     formatted(.init().weekday(.wide)
                    gettext(" through %{formatted_date}", formatted_date: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards))

         %AlertSummary.Timeframe.Time{} ->
               ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##   .formatted(date: .omitted, time: .shortened))
                              gettext(" through %{formatted_date}", formatted_date: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards))

         %AlertSummary.Timeframe.StartingTomorrow{} ->
                         gettext(" starting tomorrow")

         %AlertSummary.Timeframe.StartingLaterToday{} ->
                         ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##   .formatted(date: .omitted, time: .shortened))
            gettext(" starting **%{formatted_time}** today", formatted_time: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards)),
         %AlertSummary.Timeframe.TimeRange{} ->
          gettext(" from %{start_time} to %{end_time}", start_time: )
            String(format:
                NSLocalizedString(
                    "",
                    comment: """
                    Alert summary timeframe with a range today that will recur in the future, \
                    e.g. “from 9:00 PM to end of service”. The leading space should be retained.
                    """
                ), Self.timeRangeBoundary(timeframe.startTime),
                Self.timeRangeBoundary(timeframe.endTime))
        case .unknown: ""
        case nil: ""

          end
        end

          @spec time_range_boundary(AlertSummary.Timeframe.TimeRange.start_time() | AlertSummary.Timeframe.TimeRange.end_time()) :: String.t()
       def time_range_boundary(boundary) do
         case boundary do
           %AlertSummary.Timeframe.TimeRange.StartOfService{} -> gettext("start of service")
           %AlertSummary.Timeframe.TimeRange.EndOfService{} -> gettext("end of service")
          ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##   .formatted(date: .omitted, time: .shortened)
           %AlertSummary.Timeframe.TimeRange.Time{} -> "#{Util.datetime_to_gtfs(boundary)}"
         _ -> nil
         end
       end

       @spec summary_recurrence(AlertSummary.Recurrence.t() | nil) :: String.t()
          def summary_recurrence(recurrence) do
        case recurrence do
        %AlertSummary.Recurrence.Daily{} ->
          summary_recurrence_end_day = summary_recurrence_end_day(recurrence.ending)

          if summary_recurrence_end_day != nil do
            gettext("daily%{recurrence_text}", recurrence_text: summary_recurrence_end_day)
          else
            ""
          end
   %AlertSummary.Recurrence.SomeDays{} ->
              summary_recurrence_end_day = summary_recurrence_end_day(recurrence.ending)
              if summary_recurrence_end_day != nil do
                gettext(" some days%{recurrence_text}", recurrence_text: summary_recurrence_end_day)
              else
                nil
              end
        _ -> nil
          end

    @spec summary_recurrence_end_day(AlertSummary.Recurrence.end_day() | nil) :: String.t() | nil
       def summary_recurrence_end_day(end_day) -> String.t() | nil do
        case end_day
         %AlertSummary.Timeframe.UntilFurtherNotice{} ->
            gettext(" until further notice")
     %AlertSummary.Timeframe.Tomorrow{} ->
            gettext(" until tomorrow")
     %AlertSummary.Timeframe.LaterDate{} ->
                     ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##   .formatted(.init().month(.abbreviated).day())
      gettext(" through %{date_formatted}", date_formatted: Util.datetime_to_gtfs(end_day.timeframe.time, rounding: :backwards))
         %AlertSummary.Timeframe.ThisWeek{} ->
                    ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##     formatted(.init().weekday(.wide)
                    gettext(" through %{formatted_date}", formatted_date: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards))

                             %AlertSummary.Timeframe.ThisWeek{} ->
          _ -> nil

                             end

end

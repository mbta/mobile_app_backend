defmodule MobileAppBackend.Alerts.FormattedAlert do
  use Gettext, backend: MobileAppBackend.Gettext
  alias MBTAV3API.Alert
alias MobileAppBackend.Alerts.AlertSummary

      @type t :: %__MODULE__{
            alert: Alert.t() | nil,
            alert_summary: AlertSummary.t(),

          }
    defstruct [:alert,
    :alert_summary,
    :effect]

    @spec effect(__MODULE__.t()) :: String.t()
    def effect(formatted_alert) do

      effect = if formatted_alert.alert != nil do
        formatted_alert.alert.effect
      else if formatted_alert.alert_summary != nil do
        formatted_alert.alert_summary.effect

    else
      :unknown
      end

      # TODO: effectString
      "**%{effect}**"
    end

  end


    @spec due_to_cause(__MODULE__.t()) :: String.t() | nil
    def due_to_cause(formatted_alert) do

      cause = cond do
        formatted_alert.alert != nil && formatted_alert.alert.cause != nil -> formatted_alert.alert.cause
        %AlertSummary.TripSpecific{cause: cause} = formatted_alert.alert_summary -> cause
        _ -> nil
      end

      # TODO: cauesLowercaseString

      cause

  end

  @spec summary(__MODULE__.t() | nil, ) :: String.t() | nil
  def summary(%{alert_summary: alert_summary} = formatted_alert, locale) do
         case alert_summary do
        %AlertSummary.AllClear{} ->
          gettext("**All clear:** Regular service%{location}" , location: summary_location(nil, location: alert_summary.location))

                %AlertSummary.Standard{} ->
                  sentence_case_effect = alert_summary.effect # TODO: SENTENCE_CASE_EFFECT
                  summary_location = summary_location(alert_summary.effect, alert_summary.location)
                  summary_timeframe = summary_timeframe(alert_summary.timeframe)
                  summary_recurrence = summary_recurrence(alert_summary.recurrence)

                  if (alert_summary.is_update) do
                    gettext("**Update:** %{sentence_case_effect}%{summary_location}%{summary_timeframe}%{summary_recurrence}", sentence_case_effect: sentence_case_effect, summary_location: summary_location, summary_timeframe: summary_timeframe, summary_recurrence: summary_recurrence)
                  else
                    gettext("**%{sentence_case_effect}**%{summary_location}%{summary_timeframe}%{summary_recurrence}", sentence_case_effect: sentence_case_effect, summary_location: summary_location, summary_timeframe: summary_timeframe, summary_recurrence: summary_recurrence)
                  end


        %AlertSumary.TripSpecific{} ->
          gettext("%{trip_identity} %{trip_effect}%{cause}%{recurrence}",
          trip_identity: summary_trip_identity(alert_summary.trip_identity),
          trip_effect: summary_trip_effect(alert_summary.trip_identity, alert_summary.effect, alert_summary.effect_stops, alert_summary.is_today),
          cause: summary_trip_cause(),
          recurrence: summary_recurrence())


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
        %AlertSummary.Unknown{} ->  alert_summary.fallback
         nil ->   nil

                end


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
        case end_day do
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


    @spec summary_trip_identity(AlertSummary.TripSpecific.trip_identity()) :: String.t()
    def summary_trip_identity(trip_identity) do
    case trip_identity do
        %AlertSummary.TripSpecific.TripFrom{} ->
                    ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##    .formatted(date: .omitted, time: .shortened)
                gettext("**%{trip_time}** from **%{stop_name}**", trip_time: trip_identity.trip_time, stop_name: trip_identity.stop_name)

            %AlertSummary.TripSpecific.TripTo{} ->
                                  ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
          ##    .formatted(date: .omitted, time: .shortened)
                gettext("**%{trip_time}* to **%{headsign}**", trip_time: trip_identity.trip_time, headsign: trip_identity.headsign)

         %AlertSummary.TripSpecific.MultipleTrips{} -> gettext("Multiple trips")
    end
    end

    @spec summary_trip_effect(AlertSummary.TripSpecfic.trip_identity(), Alert.effect(), [String.t()] | nil, bool()) :: String.t()
    def summary_trip_effect(trip_identity, effect, effect_stops, is_today) do
      day = is_today ? gettext("today") : gettext("tomorrow")
      is_plural = match?(%AlertSummary.TripSpecific.MultipleTrips{}, trip_identity)
        cond do
        case effect == :cancellation && is_plural -> gettext("are cancelled %{day}", day: day)
        case .cancellation: return String(format: NSLocalizedString(
                "is cancelled %@",
                comment: "Trip specific alert effect denoting cancellation, will specify “today” or “tomorrow”"
            ), day)
        case .stationClosure: if let effectStops {
                return String(
                    format: NSLocalizedString(
                        "will not stop at %@ %@",
                        comment: "Trip specific alert effect denoting station bypass, ex “will not stop at [Back Bay and Ruggles] [today]”"
                    ),
                    effectStops.map { "**\($0)**" }.reduce(nil) { lhs, rhs in
                        if let lhs { String(
                            format: NSLocalizedString(
                                "%1$@ and %2$@",
                                comment: "Joins two stops into a list, ex “[Back Bay] and [Ruggles]”"
                            ),
                            lhs,
                            rhs
                        ) } else { rhs }
                    } ?? "",
                    day
                )
            }
        case .suspension where isPlural: return String(format: NSLocalizedString(
                "are suspended %@",
                comment: "Multiple trip specific alert effect denoting suspension, will specify “today” or “tomorrow”"
            ), day)
        case .suspension: return String(format: NSLocalizedString(
                "is suspended %@",
                comment: "Trip specific alert effect denoting suspension, will specify “today” or “tomorrow”"
            ), day)
        default:
            break
        }
        return String(
            format: NSLocalizedString(
                "affected by %@ %@",
                comment: "Trip specific alert effect fallback, ex “affected by [snow route] [today]”"
            ),
            effect.effectSentenceCaseString,
            day
        )
    end

end

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
          gettext("**All clear:** Regular service%{location}")
                #), Self.summaryLocation(effect: nil, location: alertSummary.location)

                %AlertSummary.Summary{} ->
            let args = [
                sentenceCaseEffect,
                Self.summaryLocation(effect: alertSummary.effect, location: alertSummary.location),
                Self.summaryTimeframe(timeframe: alertSummary.timeframe),
                Self.summaryRecurrence(recurrence: alertSummary.recurrence),
            ]
            if alertSummary.isUpdate {
                return AttributedString.tryMarkdown(String(format:
                    NSLocalizedString(
                        "**Update:** %1$@%2$@%3$@%4$@",
                        comment: """
                        Alert summary in the format of "Update: [Alert effect][at location][through timeframe][until recurrence]", \
                        ex "[Update][Stop closed][ at Haymarket][ through this Friday][]" or \
                        "[Update][Service suspended][ from Alewife to Harvard][ through end of service][ daily until Friday]"
                        """
                    ), args.map { $0 as CVarArg }))
            } else {
                return AttributedString.tryMarkdown(String(format:
                    NSLocalizedString(
                        "**%1$@**%2$@%3$@%4$@",
                        comment: """
                        Alert summary in the format of "[Alert effect][at location][through timeframe][until recurrence]", \
                        ex "[Stop closed][ at Haymarket][ through this Friday][]" or \
                        "[Service suspended][ from Alewife to Harvard][ through end of service][ daily until Friday]"
                        """
                    ), args.map { $0 as CVarArg }))
            }
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

alias MobileAppBackend.Alerts.AlertSummary
  @spec summary_location(Alert.Effect.t() | nil, AlertSummary.Location.t() | nil) :: String.t()
    def summary_location(effect, location) -> String {
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

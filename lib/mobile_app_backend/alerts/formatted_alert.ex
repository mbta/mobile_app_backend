# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting

defmodule MobileAppBackend.Alerts.FormattedAlert do
  use Gettext, backend: MobileAppBackend.Gettext
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.{Location, Recurrence, Timeframe, TripShuttle}
  alias MobileAppBackend.Alerts.DirectionLabel
  alias MobileAppBackend.PresentationStrings

  @type t :: %__MODULE__{
          alert: Alert.t() | nil,
          alert_summary: AlertSummary.t()
        }
  defstruct [:alert, :alert_summary, :effect]

  @spec summary(__MODULE__.t() | nil, Gettext.locale(), boolean()) :: String.t() | nil
  @doc """
  Build a localized string representing the summarized alert.
  If include_bolding is true, elements that should be emphasized will be surrounded by **, ex: "**element to emphasize**"
  """
  def summary(%{alert_summary: alert_summary} = formatted_alert, locale, include_bolding \\ false) do
    summary_with_bolding =
      Gettext.with_locale(locale, fn ->
        case alert_summary do
          %AlertSummary.AllClear{} ->
            gettext("**All clear:** Regular service%{location}",
              location: summary_location(nil, alert_summary.location)
            )

          %AlertSummary.Standard{} ->
            effect_sentence_case = effect_sentence_case(formatted_alert)
            summary_location = summary_location(alert_summary.effect, alert_summary.location)
            summary_timeframe = summary_timeframe(alert_summary.timeframe)
            summary_recurrence = summary_recurrence(alert_summary.recurrence)

            if alert_summary.is_update do
              gettext(
                "**Update:** %{effect_sentence_case}%{summary_location}%{summary_timeframe}%{summary_recurrence}",
                effect_sentence_case: effect_sentence_case,
                summary_location: summary_location,
                summary_timeframe: summary_timeframe,
                summary_recurrence: summary_recurrence
              )
            else
              gettext(
                "**%{effect_sentence_case}**%{summary_location}%{summary_timeframe}%{summary_recurrence}",
                effect_sentence_case: effect_sentence_case,
                summary_location: summary_location,
                summary_timeframe: summary_timeframe,
                summary_recurrence: summary_recurrence
              )
            end

          %AlertSummary.TripSpecific{} ->
            gettext("%{trip_identity} %{trip_effect}%{cause}%{recurrence}",
              trip_identity: summary_trip_identity(alert_summary.trip_identity),
              trip_effect:
                summary_trip_effect(
                  alert_summary.trip_identity,
                  alert_summary.effect,
                  alert_summary.effect_stops,
                  alert_summary.is_today
                ),
              cause:
                formatted_alert
                |> due_to_cause()
                |> summary_trip_cause(),
              recurrence: summary_recurrence(alert_summary.recurrence)
            )

          %AlertSummary.TripShuttle{} ->
            trip_shuttle_summary(alert_summary)

          %AlertSummary.Unknown{} ->
            alert_summary.fallback

          _ ->
            nil
        end
      end)

    if include_bolding do
      summary_with_bolding
    else
      String.replace(summary_with_bolding, "**", "")
    end
  end

  @spec summary_location(Alert.effect() | nil, Location.t() | nil) :: String.t()
  def summary_location(effect, location) do
    case location do
      %Location.DirectionToStop{} ->
        gettext(" from **%{direction_name}** stops to **%{end_stop_name}**",
          direction_name: DirectionLabel.direction_name_formatted(location.direction.name),
          end_stop_name: location.end_stop_name
        )

      %Location.SingleStop{} ->
        gettext(" at **%{stop_name}**", stop_name: location.stop_name)

      %Location.StopToDirection{} ->
        gettext(" from **%{stop_name}** to **%{direction_name}** stops",
          stop_name: location.start_stop_name,
          direction_name: DirectionLabel.direction_name_formatted(location.direction.name)
        )

      %Location.SuccessiveStops{} ->
        gettext(" from **%{start_stop}** to **%{end_stop}**",
          start_stop: location.start_stop_name,
          end_stop: location.end_stop_name
        )

      %Location.WholeRoute{} ->
        if effect == :shuttle do
          gettext(" replacing **%{mode_label}**",
            mode_label: Location.WholeRoute.mode_label(location)
          )
        else
          gettext(" on **%{mode_label}**",
            mode_label: Location.WholeRoute.mode_label(location)
          )
        end

      _ ->
        ""
    end
  end

  @spec summary_timeframe(Timeframe.t() | nil) :: String.t()
  def summary_timeframe(timeframe) do
    case timeframe do
      %Timeframe.UntilFurtherNotice{} ->
        gettext(" until further notice")

      %Timeframe.EndOfService{} ->
        gettext(" through end of service")

      %Timeframe.Tomorrow{} ->
        gettext(" through tomorrow")

      %Timeframe.LaterDate{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##     .formatted(.init().month(.abbreviated).day()))
        gettext(" through %{formatted_date}",
          formatted_date: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards)
        )

      %Timeframe.ThisWeek{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##     formatted(.init().weekday(.wide)
        gettext(" through %{formatted_date}",
          formatted_date: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards)
        )

      %Timeframe.Time{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##   .formatted(date: .omitted, time: .shortened))
        gettext(" through %{formatted_date}",
          formatted_date: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards)
        )

      %Timeframe.StartingTomorrow{} ->
        gettext(" starting tomorrow")

      %Timeframe.StartingLaterToday{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##   .formatted(date: .omitted, time: .shortened))
        gettext(" starting **%{formatted_time}** today",
          formatted_time: Util.datetime_to_gtfs(timeframe.time, rounding: :backwards)
        )

      %Timeframe.TimeRange{} ->
        gettext(" from %{start_time} to %{end_time}",
          start_time: time_range_boundary(timeframe.start_time),
          end_time: time_range_boundary(timeframe.end_time)
        )

      _ ->
        ""
    end
  end

  @spec time_range_boundary(
          Timeframe.TimeRange.start_time()
          | Timeframe.TimeRange.end_time()
        ) :: String.t()
  defp time_range_boundary(boundary) do
    case boundary do
      %Timeframe.TimeRange.StartOfService{} -> gettext("start of service")
      %Timeframe.TimeRange.EndOfService{} -> gettext("end of service")
      ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
      ##   .formatted(date: .omitted, time: .shortened)
      %Timeframe.TimeRange.Time{} -> "#{Util.datetime_to_gtfs(boundary.time)}"
      _ -> nil
    end
  end

  @spec summary_recurrence(Recurrence.t() | nil) :: String.t()
  def summary_recurrence(recurrence) do
    case recurrence do
      %Recurrence.Daily{} ->
        summary_recurrence_end_day = summary_recurrence_end_day(recurrence.ending)

        if summary_recurrence_end_day != nil do
          gettext(" daily%{recurrence_text}", recurrence_text: summary_recurrence_end_day)
        else
          ""
        end

      %Recurrence.SomeDays{} ->
        summary_recurrence_end_day = summary_recurrence_end_day(recurrence.ending)

        if summary_recurrence_end_day != nil do
          gettext(" some days%{recurrence_text}", recurrence_text: summary_recurrence_end_day)
        else
          nil
        end

      _ ->
        nil
    end
  end

  @spec summary_recurrence_end_day(Recurrence.end_day() | nil) :: String.t() | nil
  defp summary_recurrence_end_day(end_day) do
    case end_day do
      %Timeframe.UntilFurtherNotice{} ->
        gettext(" until further notice")

      %Timeframe.Tomorrow{} ->
        gettext(" until tomorrow")

      %Timeframe.LaterDate{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##   .formatted(.init().month(.abbreviated).day())
        gettext(" through %{date_formatted}",
          date_formatted: Util.datetime_to_gtfs(end_day.time, rounding: :backwards)
        )

      %Timeframe.ThisWeek{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##     formatted(.init().weekday(.wide)
        gettext(" through %{formatted_date}",
          formatted_date: Util.datetime_to_gtfs(end_day.time, rounding: :backwards)
        )

      _ ->
        nil
    end
  end

  @spec summary_trip_identity(AlertSummary.TripSpecific.trip_identity()) :: String.t()
  def summary_trip_identity(trip_identity) do
    case trip_identity do
      %AlertSummary.TripSpecific.ThisTrip{} ->
        gettext("This %{route_type}",
          route_type: PresentationStrings.route_type(trip_identity.route_type, true)
        )

      %AlertSummary.TripSpecific.TripFrom{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##    .formatted(date: .omitted, time: .shortened)
        gettext("**%{trip_time}** %{route_type} from **%{stop_name}**",
          trip_time: trip_identity.trip_time,
          route_type: PresentationStrings.route_type(trip_identity.route_type, true),
          stop_name: trip_identity.stop_name
        )

      %AlertSummary.TripSpecific.TripTo{} ->
        ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
        ##    .formatted(date: .omitted, time: .shortened)
        gettext("**%{trip_time}* %{route_type} to **%{headsign}**",
          trip_time: trip_identity.trip_time,
          route_type: PresentationStrings.route_type(trip_identity.route_type, true),
          headsign: trip_identity.headsign
        )

      %AlertSummary.TripSpecific.MultipleTrips{} ->
        gettext("Multiple trips")
    end
  end

  @spec trip_shuttle_summary(TripShuttle.t()) :: String.t()
  def trip_shuttle_summary(alert_summary) do
    if match?(%TripShuttle.SingleTrip{}, alert_summary.trip_identity) &&
         alert_summary.trip_identity.from_stop_name != nil do
      gettext(
        "%{trip_identity} is replaced by shuttle buses from **%{start_stop}** to **%{end_stop}%{recurrence}",
        trip_identity: summary_trip_shuttle_identity(alert_summary.trip_identity),
        start_stop: alert_summary.start_stop_name,
        end_stop: alert_summary.end_stop_name,
        recurrence: summary_recurrence(alert_summary.recurrence)
      )
    else
      gettext(
        "Shuttle buses replace %{trip_identity} from **%{start_stop}** to **%{end_stop}**%{recurrence}",
        trip_identity: summary_trip_shuttle_identity(alert_summary.trip_identity),
        start_stop: alert_summary.start_stop_name,
        end_stop: alert_summary.end_stop_name,
        recurrence: summary_recurrence(alert_summary.recurrence)
      )
    end
  end

  @spec summary_trip_shuttle_identity(AlertSummary.TripShuttle.trip_identity()) :: String.t()
  def summary_trip_shuttle_identity(trip_identity) do
    ## ********************** TODO: KB COME BACK AND TRANSLATE THE DATE!!! **************************
    ##    .formatted(date: .omitted, time: .shortened)
    case trip_identity do
      %AlertSummary.TripShuttle.SingleTrip{} ->
        if trip_identity.from_stop_name != nil do
          gettext("the **%{time}** %{vehicle} from %{from_stop}",
            time: trip_identity.trip_time,
            vehicle:
              MobileAppBackend.PresentationStrings.route_type(trip_identity.route_type, true),
            from_stop: trip_identity.from_stop_name
          )
        else
          gettext("the **%{time}* %{vehicle}",
            time: trip_identity.trip_time,
            vehicle:
              MobileAppBackend.PresentationStrings.route_type(trip_identity.route_type, true)
          )
        end

      %AlertSummary.TripShuttle.ThisTrip{} ->
        gettext("this %{vehicle}",
          vehicle: MobileAppBackend.PresentationStrings.route_type(trip_identity.route_type, true)
        )

      %AlertSummary.TripShuttle.MultipleTrips{} ->
        gettext("multiple trips")
    end
  end

  @spec resolved_effect(__MODULE__.t()) :: Alert.effect()
  defp resolved_effect(formatted_alert) do
    cond do
      formatted_alert.alert != nil -> formatted_alert.alert.effect
      formatted_alert.alert_summary != nil -> formatted_alert.alert_summary.effect
      true -> :unknown
    end
  end

  @spec effect_sentence_case(__MODULE__.t()) :: String.t()
  defp effect_sentence_case(formatted_alert) do
    formatted_alert
    |> resolved_effect()
    |> PresentationStrings.effect_sentence_case()
  end

  @spec due_to_cause(__MODULE__.t()) :: String.t() | nil
  defp due_to_cause(formatted_alert) do
    cause =
      cond do
        formatted_alert.alert != nil && formatted_alert.alert.cause != nil ->
          formatted_alert.alert.cause

        match?(%AlertSummary.TripSpecific{}, formatted_alert.alert_summary) ->
          formatted_alert.alert_summary.cause

        true ->
          nil
      end

    PresentationStrings.cause_lower_case(cause)
  end

  @spec summary_trip_effect(
          AlertSummary.TripSpecific.trip_identity(),
          Alert.effect(),
          [String.t()] | nil,
          bool()
        ) :: String.t()
  def summary_trip_effect(trip_identity, effect, effect_stops, is_today) do
    day = if is_today, do: gettext("today"), else: gettext("tomorrow")
    is_plural = match?(%AlertSummary.TripSpecific.MultipleTrips{}, trip_identity)

    cond do
      effect == :cancellation && is_plural ->
        gettext("are cancelled %{day}", day: day)

      effect == :cancellation ->
        gettext("is cancelled %{day}", day: day)

      effect in [:station_closure, :stop_closure, :dock_closure] && effect_stops != nil ->
        gettext("will not stop at %{stop_list} %{day}",
          day: day,
          stop_list:
            effect_stops
            |> Enum.map(&"**#{&1}**")
            |> Enum.reverse()
            |> Enum.reduce("", fn stop, acc ->
              if acc == "" do
                stop
              else
                gettext("%{stop} and %{other_stops}", stop: stop, other_stops: acc)
              end
            end)
        )

      effect == :suspension ->
        first_effected_stop =
          effect_stops
          |> List.wrap()
          |> List.first()

        cond do
          first_effected_stop != nil ->
            gettext("will terminate at %{terminating_stop}, %{day}",
              terminating_stop: first_effected_stop,
              day: day
            )

          is_plural ->
            gettext("are suspended %{day}", day: day)

          true ->
            gettext("is suspended %{day}", day: day)
        end

      true ->
        gettext("affected by %{effect} %{day}",
          effect: PresentationStrings.effect_sentence_case(effect),
          day: day
        )
    end
  end

  @spec summary_trip_cause(String.t() | nil) :: String.t()
  defp summary_trip_cause(due_to_cause) do
    if due_to_cause != nil do
      gettext(" due to %{cause}", cause: due_to_cause)
    else
      ""
    end
  end
end

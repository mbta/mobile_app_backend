defmodule MobileAppBackend.Alerts.FormattedAlert do
  use Gettext, backend: MobileAppBackend.Gettext
  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.AlertSummary.TripShuttle
  alias MobileAppBackend.Alerts.FormattedAlert.{TemplateFragments, Templates}
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
  def summary(
        %{alert: alert, alert_summary: alert_summary} = formatted_alert,
        locale,
        include_bolding \\ false
      ) do
    summary_with_bolding =
      Gettext.with_locale(locale, fn ->
        case alert_summary do
          %AlertSummary.AllClear{} ->
            gettext("**All clear:** Regular service%{location}",
              location: TemplateFragments.location(nil, alert_summary.location)
            )

          %AlertSummary.Standard{} ->
            location = TemplateFragments.location(alert_summary.effect, alert_summary.location)
            timeframe = TemplateFragments.timeframe(alert_summary.timeframe)
            recurrence = TemplateFragments.recurrence(alert_summary.recurrence)

            Templates.standard(
              alert,
              location,
              timeframe,
              recurrence,
              alert_summary.is_update
            )

          %AlertSummary.TripSpecific{} ->
            trip_identity = summary_trip_identity(alert_summary.trip_identity)

            trip_effect =
              TemplateFragments.trip_effect(
                alert_summary.trip_identity,
                alert_summary.effect,
                alert_summary.effect_stops,
                alert_summary.is_today
              )

            cause =
              formatted_alert
              |> cause_lower_case()
              |> TemplateFragments.due_to_cause()

            recurrence = TemplateFragments.recurrence(alert_summary.recurrence)
            Templates.trip_specific(trip_identity, trip_effect, cause, recurrence)

          %AlertSummary.TripShuttle{} ->
            one_trip? =
              match?(%TripShuttle.SingleTrip{}, alert_summary.trip_identity) &&
                alert_summary.trip_identity.from_stop_name != nil

            trip_identity = summary_trip_shuttle_identity(alert_summary.trip_identity)
            start_stop = alert_summary.start_stop_name
            end_stop = alert_summary.end_stop_name
            recurrence = TemplateFragments.recurrence(alert_summary.recurrence)

            Templates.trip_shuttle(trip_identity, start_stop, end_stop, recurrence, one_trip?)

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

  @spec summary_trip_identity(AlertSummary.TripSpecific.trip_identity()) :: String.t()
  def summary_trip_identity(trip_identity) do
    case trip_identity do
      %AlertSummary.TripSpecific.ThisTrip{} ->
        gettext("This %{route_type}",
          route_type: PresentationStrings.route_type(trip_identity.route_type, true)
        )

      %AlertSummary.TripSpecific.TripFrom{} ->
        gettext("**%{trip_time}** %{route_type} from **%{stop_name}**",
          trip_time: Util.DateTime.datetime_to_string(trip_identity.trip_time, :short_time),
          route_type: PresentationStrings.route_type(trip_identity.route_type, true),
          stop_name: trip_identity.stop_name
        )

      %AlertSummary.TripSpecific.TripTo{} ->
        gettext("**%{trip_time}** %{route_type} to **%{headsign}**",
          trip_time: Util.DateTime.datetime_to_string(trip_identity.trip_time, :short_time),
          route_type: PresentationStrings.route_type(trip_identity.route_type, true),
          headsign: trip_identity.headsign
        )

      %AlertSummary.TripSpecific.MultipleTrips{} ->
        gettext("Multiple trips")
    end
  end

  @spec summary_trip_shuttle_identity(AlertSummary.TripShuttle.trip_identity()) :: String.t()
  def summary_trip_shuttle_identity(trip_identity) do
    case trip_identity do
      %AlertSummary.TripShuttle.SingleTrip{} ->
        if trip_identity.from_stop_name != nil do
          gettext("**%{time}** %{vehicle} from **%{from_stop}**",
            time: Util.DateTime.datetime_to_string(trip_identity.trip_time, :short_time),
            vehicle:
              MobileAppBackend.PresentationStrings.route_type(trip_identity.route_type, true),
            from_stop: trip_identity.from_stop_name
          )
        else
          gettext("the **%{time}** %{vehicle}",
            time: Util.DateTime.datetime_to_string(trip_identity.trip_time, :short_time),
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

  @spec cause_lower_case(__MODULE__.t()) :: String.t() | nil
  defp cause_lower_case(formatted_alert) do
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
end

# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule MobileAppBackend.Alerts.FormattedAlert.TemplateFragments do
  @moduledoc """
  Fragments of strings to be combined and used in `MobileAppBackend.Alerts.FormattedAlert.Templates`
  These functions produce strings that can't stand on their own; strings that can be used outside of summaries should
  live in `MobileAppBackend.PresentationStrings`.
  """
  alias MBTAV3API.{Alert, Stop}
  alias MobileAppBackend.Alerts.AlertSummary.{Location, Recurrence, Timeframe}
  alias MobileAppBackend.Alerts.DirectionLabel
  alias MobileAppBackend.PresentationStrings

  use Gettext, backend: MobileAppBackend.Gettext

  ### Stops / Location ###

  @spec location(Alert.effect() | nil, Location.t() | [Stop.id()] | nil) :: String.t()
  def location(effect, location) do
    case location do
      %Location.DirectionToStop{} ->
        gettext_comment(
          ~s|Alert summary location for branching routes in the format of " from [direction] stops to [Stop name]" ex. " from [Westbound] stops to [Kenmore]" or " from [Eastbound] stops to [Government Center]". The leading space should be retained for interpolation into a full alert summary template.|
        )

        gettext(" from **%{direction_name}** stops to **%{end_stop_name}**",
          direction_name: DirectionLabel.direction_name_formatted(location.direction.name),
          end_stop_name: location.end_stop_name
        )

      %Location.SingleStop{} ->
        gettext_comment(
          ~s|Alert summary location for a single stop in the format of " at [Stop name]" ex. " at [Haymarket]" or " at [Green St @ Magazine St]". The leading space should be retained for interpolation into a full alert summary template.|
        )

        gettext(" at **%{stop_name}**", stop_name: location.stop_name)

      %Location.StopToDirection{} ->
        gettext_comment(
          ~s|Alert summary location for branching routes in the format of " from [Stop name] to [direction] stops" ex. " from [Kenmore] to [Westbound] stops" or " from [JFK/UMass] to [Southbound] stops". The leading space should be retained for interpolation into a full alert summary template.|
        )

        gettext(" from **%{stop_name}** to **%{direction_name}** stops",
          stop_name: location.start_stop_name,
          direction_name: DirectionLabel.direction_name_formatted(location.direction.name)
        )

      %Location.SuccessiveStops{} ->
        gettext_comment(
          ~s|Alert summary location for consecutive stops in the format of " from [Stop name] to [Other stop name]" ex. " from [Alewife] to [Harvard]" or " from [Lechmere] to [Park Street]". The leading space should be retained for interpolation into a full alert summary template.|
        )

        gettext(" from **%{start_stop}** to **%{end_stop}**",
          start_stop: location.start_stop_name,
          end_stop: location.end_stop_name
        )

      %Location.WholeRoute{} ->
        if effect == :shuttle do
          gettext_comment(
            ~s|Alert summary location for an entire route with shuttle service in the format of " replacing [RouteLabel]" ex. " replacing [Green Line C]" or " replacing [Orangle Line]". The leading space should be retained for interpolation into a full alert summary template.|
          )

          gettext(" replacing **%{mode_label}**",
            mode_label: PresentationStrings.mode_label(location.route_label, location.route_type)
          )
        else
          gettext_comment(
            ~s|Alert summary location for an entire route in the format of " on [RouteLabel]" ex. " on [Green Line C]" or " on [1 bus]". The leading space should be retained for interpolation into a full alert summary template.|
          )

          gettext(" on **%{mode_label}**",
            mode_label: PresentationStrings.mode_label(location.route_label, location.route_type)
          )
        end

      %Location.AffectedStops{} ->
        gettext_comment(
          ~s|Alert summary when there are multiple locations For example "Service suspended at [Downtown Crossing and Oak Grove]" or "Service suspended at [multiple stops]"|
        )

        gettext(" at %{stop_list}", stop_list: affected_stop_list(location.stops))

      stops when is_list(stops) ->
        gettext_comment(
          ~s|Alert summary when there are multiple locations For example "Service suspended at [Downtown Crossing and Oak Grove]" or "Service suspended at [multiple stops]"|
        )

        gettext(" at %{stop_list}", stop_list: affected_stop_list(stops))

      %Location.Omit{} ->
        ""

      _ ->
        ""
    end
  end

  @spec skipped_effect(String.t(), String.t()) :: String.t()
  def skipped_effect(affected_stops_location, timeframe) do
    gettext_comment(
      "Alert effect denoting station bypass, ex “will not stop[ at Back Bay and Ruggles] [today]”"
    )

    gettext("will not stop%{affected_stops_location} %{timeframe}",
      timeframe: timeframe,
      affected_stops_location: affected_stops_location
    )
  end

  @spec affected_stop_list([Stop.id()]) :: String.t()
  def affected_stop_list(stops) do
    if length(stops) > 3 do
      gettext_comment("Used when more than 3 stops are affected")
      gettext("**multiple stops**")
    else
      formatted_stops =
        stops
        |> Enum.map(&"**#{&1}**")

      Cldr.List.to_string!(formatted_stops)
    end
  end

  ### Delays ###

  def delay_duration(severity) do
    raw = PresentationStrings.delay_duration(severity)
    if raw == "", do: "", else: " #{raw}"
  end

  ### Recurrence ###

  @spec recurrence(Recurrence.t() | nil) :: String.t()
  def recurrence(recurrence) do
    case recurrence do
      %Recurrence.Daily{} ->
        summary_recurrence_end_day = recurrence_end_day(recurrence.ending)

        if summary_recurrence_end_day != nil do
          gettext_comment(
            "Alert summary recurrence every day until the indicated date, e.g. “ daily[ until Friday]”. The leading space must be retained."
          )

          gettext(" daily%{recurrence_text}", recurrence_text: summary_recurrence_end_day)
        else
          ""
        end

      %Recurrence.SomeDays{} ->
        summary_recurrence_end_day = recurrence_end_day(recurrence.ending)

        if summary_recurrence_end_day != nil do
          gettext_comment(
            "Alert summary recurrence on only certain days until the indicated date, e.g. “some days until Jan 16”. The leading space must be retained."
          )

          gettext(" some days%{recurrence_text}", recurrence_text: summary_recurrence_end_day)
        else
          nil
        end

      _ ->
        nil
    end
  end

  @spec recurrence_end_day(Recurrence.end_day() | nil) :: String.t() | nil
  defp recurrence_end_day(end_day) do
    case end_day do
      %Timeframe.UntilFurtherNotice{} ->
        gettext_comment(
          "Alert summary timeframe with no known end. The leading space should be retained."
        )

        gettext(" until further notice")

      %Timeframe.Tomorrow{} ->
        gettext_comment(
          "Alert summary recurrence ending tomorrow. The leading space should be retained."
        )

        gettext(" until tomorrow")

      %Timeframe.LaterDate{} ->
        gettext_comment(
          ~s|Alert summary recurrence ending on a specific date in the future. ex. " until May 11". The date component is localized by the OS. The leading space should be retained.|
        )

        gettext("key/alert_summary_recurrence_end_day_later_date",
          "1":
            end_day.time
            |> Util.DateTime.datetime_to_gtfs(rounding: :backwards)
            |> Util.DateTime.datetime_to_string(:short_month_day)
        )

      %Timeframe.ThisWeek{} ->
        gettext_comment(
          ~s|Alert summary recurrence ending on a specific day later this week. ex. " until Thursday". The weekday component is localized by the OS. The leading space should be retained.|
        )

        gettext("key/alert_summary_recurrence_end_day_this_week",
          "1":
            end_day.time
            |> Util.DateTime.datetime_to_gtfs(rounding: :backwards)
            |> Util.DateTime.datetime_to_string(:wide_weekday)
        )

      _ ->
        nil
    end
  end

  ### Cause ###
  @spec due_to_cause(Alert.cause() | String.t() | nil) :: String.t()

  def due_to_cause(due_to_cause) when not is_nil(due_to_cause) and is_atom(due_to_cause) do
    due_to_cause
    |> PresentationStrings.cause_lower_case()
    |> due_to_cause()
  end

  def due_to_cause(due_to_cause) when is_binary(due_to_cause) or is_nil(due_to_cause) do
    if due_to_cause != nil do
      gettext_comment(
        ~s|An alert cause interpolated into an alert summary: ex. "due to [maintenance]", in a longer string like "Trip 101 experiencing delays of about 10 minutes today due to maintenance daily until Friday"|
      )

      gettext(" due to %{cause}", cause: due_to_cause)
    else
      ""
    end
  end

  ### Timeframe ###

  def until_further_notice do
    gettext_comment(
      "Alert summary timeframe with no known end. The leading space should be retained."
    )

    gettext(" until further notice")
  end

  def until_later_today do
    gettext_comment(
      "Alert summary timeframe ending today at an unspecified time. The leading space should be retained."
    )

    gettext(" until later today")
  end

  def indefinite_end_time_strings, do: [until_further_notice(), until_later_today()]

  @spec timeframe(Timeframe.t() | nil) :: String.t()
  def timeframe(timeframe) do
    case timeframe do
      %Timeframe.UntilFurtherNotice{} ->
        until_further_notice()

      %Timeframe.EndOfService{} ->
        gettext_comment(
          "Alert summary timeframe ending at the end of service on the current day. The leading space should be retained for interpolation into a full alert summary template."
        )

        gettext(" through end of service")

      %Timeframe.LaterToday{} ->
        until_later_today()

      %Timeframe.Tomorrow{} ->
        gettext_comment(
          "Alert summary timeframe ending tomorrow. The leading space should be retained for interpolation into a full alert summary template."
        )

        gettext(" through tomorrow")

      %Timeframe.LaterDate{} ->
        gettext_comment(
          ~s|Alert summary timeframe ending on a specific date in the future. ex. " through May 11". The date component is localized by the OS. The leading space should be retained, because this will be added in the %3 position of the "**%1$@**%2$@%3$@" alert summary template which may or may not include a timeframe fragment.|
        )

        gettext("key/alert_summary_timeframe_later_date",
          "1":
            timeframe.time
            |> Util.DateTime.datetime_to_gtfs(rounding: :backwards)
            |> Util.DateTime.datetime_to_string(:short_month_day)
        )

      %Timeframe.ThisWeek{} ->
        gettext_comment(
          ~s|Alert summary timeframe ending on a specific day later this week. ex. " through Thursday". The weekday component is localized by the OS. The leading space should be retained, because this will be added in the %3 position of the "**%1$@**%2$@%3$@" alert summary template which may or may not include a timeframe fragment.|
        )

        gettext("key/alert_summary_timeframe_this_week",
          "1":
            timeframe.time
            |> Util.DateTime.datetime_to_gtfs(rounding: :backwards)
            |> Util.DateTime.datetime_to_string(:wide_weekday)
        )

      %Timeframe.Time{} ->
        gettext_comment(
          ~s|Alert summary timeframe ending on a specific time later today. ex. " through 10:00 PM". The time component is localized by the OS. The leading space should be retained, because this will be added in the %3 position of the "**%1$@**%2$@%3$@" alert summary template which may or may not include a timeframe fragment.|
        )

        gettext("key/alert_summary_timeframe_time",
          "1": Util.DateTime.datetime_to_string(timeframe.time, :short_time)
        )

      %Timeframe.StartingTomorrow{} ->
        gettext_comment(
          "Alert summary timeframe starting tomorrow. The leading space should be retained for interpolation into a full alert summary template."
        )

        gettext(" starting tomorrow")

      %Timeframe.StartingLaterToday{} ->
        gettext_comment(
          ~s|Alert summary timeframe starting on a specific time later today. ex. " starting 10:00 PM today". The time component is localized by the OS. The leading space should be retained for interpolation into a full alert summary template.|
        )

        gettext(" starting **%{formatted_time}** today",
          formatted_time: Util.DateTime.datetime_to_string(timeframe.time, :short_time)
        )

      %Timeframe.TimeRange{} ->
        gettext_comment(
          "Alert summary timeframe with a range today that will recur in the future, e.g. “from 9:00 PM to end of service”. The leading space should be retained."
        )

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
      %Timeframe.TimeRange.StartOfService{} ->
        gettext_comment("Used when an alert begins at the start of a service day")
        gettext("start of service")

      %Timeframe.TimeRange.EndOfService{} ->
        gettext_comment("Used when an alert ends at the end of a service day")
        gettext("end of service")

      %Timeframe.TimeRange.Time{} ->
        Util.DateTime.datetime_to_string(boundary.time, :short_time)

      _ ->
        nil
    end
  end
end

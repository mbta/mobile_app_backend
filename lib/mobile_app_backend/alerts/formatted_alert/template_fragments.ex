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
            mode_label: PresentationStrings.mode_label(location.route_label, location.route_type)
          )
        else
          gettext(" on **%{mode_label}**",
            mode_label: PresentationStrings.mode_label(location.route_label, location.route_type)
          )
        end

      %Location.AffectedStops{} ->
        affected_stop_list(location.stops)

      stops when is_list(stops) ->
        affected_stop_list(stops)

      _ ->
        ""
    end
  end

  @spec skipped_effect(String.t(), String.t()) :: String.t()
  def skipped_effect(stops, timeframe) do
    gettext("will not stop at %{stop_list} %{timeframe}",
      timeframe: timeframe,
      stop_list: stops
    )
  end

  @spec affected_stop_list([Stop.id()]) :: String.t()
  def affected_stop_list(stops) do
    if length(stops) > 3 do
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
          gettext(" daily%{recurrence_text}", recurrence_text: summary_recurrence_end_day)
        else
          ""
        end

      %Recurrence.SomeDays{} ->
        summary_recurrence_end_day = recurrence_end_day(recurrence.ending)

        if summary_recurrence_end_day != nil do
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
        gettext(" until further notice")

      %Timeframe.Tomorrow{} ->
        gettext(" until tomorrow")

      %Timeframe.LaterDate{} ->
        gettext("key/alert_summary_recurrence_end_day_later_date",
          "1":
            end_day.time
            |> Util.DateTime.datetime_to_gtfs(rounding: :backwards)
            |> Util.DateTime.datetime_to_string(:short_month_day)
        )

      %Timeframe.ThisWeek{} ->
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
      gettext(" due to %{cause}", cause: due_to_cause)
    else
      ""
    end
  end

  ### Timeframe ###

  @until_further_notice " until further notice"
  @until_later_today " until later today"
  def indefinite_end_time_strings, do: [@until_further_notice, @until_later_today]

  @spec timeframe(Timeframe.t() | nil) :: String.t()
  def timeframe(timeframe) do
    case timeframe do
      %Timeframe.UntilFurtherNotice{} ->
        gettext(@until_further_notice)

      %Timeframe.EndOfService{} ->
        gettext(" through end of service")

      %Timeframe.LaterToday{} ->
        gettext(@until_later_today)

      %Timeframe.Tomorrow{} ->
        gettext(" through tomorrow")

      %Timeframe.LaterDate{} ->
        gettext("key/alert_summary_timeframe_later_date",
          "1":
            timeframe.time
            |> Util.DateTime.datetime_to_gtfs(rounding: :backwards)
            |> Util.DateTime.datetime_to_string(:short_month_day)
        )

      %Timeframe.ThisWeek{} ->
        gettext("key/alert_summary_timeframe_this_week",
          "1":
            timeframe.time
            |> Util.DateTime.datetime_to_gtfs(rounding: :backwards)
            |> Util.DateTime.datetime_to_string(:wide_weekday)
        )

      %Timeframe.Time{} ->
        gettext("key/alert_summary_timeframe_time",
          "1": Util.DateTime.datetime_to_string(timeframe.time, :short_time)
        )

      %Timeframe.StartingTomorrow{} ->
        gettext(" starting tomorrow")

      %Timeframe.StartingLaterToday{} ->
        gettext(" starting **%{formatted_time}** today",
          formatted_time: Util.DateTime.datetime_to_string(timeframe.time, :short_time)
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
      %Timeframe.TimeRange.StartOfService{} ->
        gettext("start of service")

      %Timeframe.TimeRange.EndOfService{} ->
        gettext("end of service")

      %Timeframe.TimeRange.Time{} ->
        Util.DateTime.datetime_to_string(boundary.time, :short_time)

      _ ->
        nil
    end
  end
end

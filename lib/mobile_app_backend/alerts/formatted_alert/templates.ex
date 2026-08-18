defmodule MobileAppBackend.Alerts.FormattedAlert.Templates do
  @moduledoc """
  Top-level templates for alert summaries.
  """
  use Gettext, backend: MobileAppBackend.Gettext

  import MobileAppBackend.Alerts.FormattedAlert.TemplateFragments
  import MobileAppBackend.PresentationStrings

  # [Vehicle type] will not stop at [Affected stop(s)] until [end time/further notice].
  def standard(%{effect: effect}, location, timeframe, _recurrence, _is_update)
      when effect in [:dock_closure, :station_closure, :stop_closure] do
    mode =
      case effect do
        :dock_closure -> gettext("Ferries")
        :station_closure -> gettext("Trains")
        :stop_closure -> gettext("Buses")
      end

    # TODO: There may be some issues with skipped_effect depending on how many stops
    gettext(
      "%{mode} %{skipped_effect}",
      mode: mode,
      skipped_effect:
        skipped_effect(
          location,
          String.trim_leading(timeframe)
        )
    )
  end

  # [Disruption description] [delay duration] [Affected stop(s)] [end time] [due to cause].
  def standard(%{effect: :delay} = alert, location, timeframe, recurrence, _is_update) do
    delay_duration = delay_duration(alert.severity)
    delay_duration = if delay_duration == "", do: "", else: " #{delay_duration}"

    gettext(
      "**Delays**%{delay_duration}%{summary_location}%{summary_timeframe}%{summary_recurrence}%{due_to_cause}",
      effect_sentence_case: effect_sentence_case(:delay),
      delay_duration: delay_duration,
      summary_location: location,
      summary_timeframe: timeframe,
      summary_recurrence: recurrence,
      due_to_cause:
        alert.cause
        |> cause_lower_case()
        |> due_to_cause()
    )
  end

  # TODO
  # Elevator closed at [Affected stop(s)] until [end time/further notice].

  # TODO: do is_update prefix separately and consistently
  def standard(%{effect: effect}, location, timeframe, recurrence, is_update) do
    if is_update do
      gettext(
        "**Update:** %{effect_sentence_case}%{summary_location}%{summary_timeframe}%{summary_recurrence}",
        effect_sentence_case: effect_sentence_case(effect),
        summary_location: location,
        summary_timeframe: timeframe,
        summary_recurrence: recurrence
      )
    else
      gettext(
        "**%{effect_sentence_case}**%{summary_location}%{summary_timeframe}%{summary_recurrence}",
        effect_sentence_case: effect_sentence_case(effect),
        summary_location: location,
        summary_timeframe: timeframe,
        summary_recurrence: recurrence
      )
    end
  end

  # TODO
  # [Disruption description] [Affected stop(s)] [end time] [due to cause].

  # TODO
  # [Disruption description] until [end time/further notice]. See alert details.

  def trip_specific(trip_identity, effect, cause, recurrence) do
    gettext("%{trip_identity} %{trip_effect}%{cause}%{recurrence}",
      trip_identity: trip_identity,
      trip_effect: effect,
      cause: cause,
      recurrence: recurrence
    )
  end

  def trip_shuttle(trip_identity, start_stop, end_stop, recurrence, one_trip?) do
    if one_trip? do
      gettext(
        "%{trip_identity} is replaced by shuttle buses from **%{start_stop}** to **%{end_stop}**%{recurrence}",
        trip_identity: trip_identity,
        start_stop: start_stop,
        end_stop: end_stop,
        recurrence: recurrence
      )
    else
      gettext(
        "Shuttle buses replace %{trip_identity} from **%{start_stop}** to **%{end_stop}**%{recurrence}",
        trip_identity: trip_identity,
        start_stop: start_stop,
        end_stop: end_stop,
        recurrence: recurrence
      )
    end
  end
end

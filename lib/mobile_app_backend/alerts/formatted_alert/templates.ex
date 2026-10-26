defmodule MobileAppBackend.Alerts.FormattedAlert.Templates do
  @moduledoc """
  Top-level templates for alert summaries.
  """
  use MobileAppBackend.Gettext

  alias MBTAV3API.Alert
  alias MobileAppBackend.Alerts.FormattedAlert.TemplateFragments
  alias MobileAppBackend.PresentationStrings

  # [Vehicle type] will not stop at [Affected stop(s)] until [end time/further notice].
  def standard(%{effect: effect}, location, timeframe, _recurrence, _context)
      when effect in [:dock_closure, :station_closure, :stop_closure] do
    # TODO: There may be some issues with skipped_effect depending on how many stops
    gettext("%{mode} %{skipped_effect}",
      comment: nil,
      mode: vehicle_type(effect, :plural),
      skipped_effect:
        TemplateFragments.skipped_effect(
          location,
          String.trim_leading(timeframe)
        )
    )
  end

  # [Disruption description] [delay duration] [Affected stop(s)] [end time] [due to cause].
  def standard(%{effect: :delay} = alert, location, timeframe, recurrence, _context) do
    gettext(
      "**Delays**%{delay_duration}%{summary_location}%{summary_timeframe}%{summary_recurrence}%{due_to_cause}",
      comment: [
        "Assemble a summary of an alert with the structure:",
        "**Delays**[ of about 15 minutes][ due to weather][ from Porter to Havard][ starting today][ daily until Friday][ due to maintenance]"
      ],
      effect_sentence_case: PresentationStrings.effect_sentence_case(:delay),
      delay_duration: TemplateFragments.delay_duration(alert.severity),
      summary_location: location,
      summary_timeframe: timeframe,
      summary_recurrence: recurrence,
      due_to_cause: TemplateFragments.due_to_cause(alert.cause)
    )
  end

  # TODO
  # Elevator closed at [Affected stop(s)] until [end time/further notice].

  # [Disruption description] until [end time/further notice]. See alert details.
  def standard(%{effect: effect} = alert, location, timeframe, recurrence, context)
      when effect in [:detour, :snow_route] and context == :notification do
    summary = default_standard(alert, location, timeframe, recurrence)

    gettext("%{summary}. See alert details.",
      comment: "Text in a notification prompting users to click to learn more",
      summary: summary
    )
  end

  # [Disruption description] [Affected stop(s)] [end time] [due to cause].
  def standard(alert, location, timeframe, recurrence, _context) do
    default_standard(alert, location, timeframe, recurrence)
  end

  defp default_standard(%{effect: effect} = alert, location, timeframe, recurrence) do
    due_to_cause =
      if location == "" || timeframe == "" ||
           timeframe in TemplateFragments.indefinite_end_time_strings() do
        TemplateFragments.due_to_cause(alert.cause)
      else
        ""
      end

    gettext(
      "**%{effect_sentence_case}**%{summary_location}%{summary_timeframe}%{summary_recurrence}%{due_to_cause}",
      comment:
        ~S"Assemble a full summary of an alert with the structure: \n**[Modified service]**[ from Porter to Havard][ starting today][ daily until Friday][ due to maintenance]",
      effect_sentence_case: PresentationStrings.effect_sentence_case(effect),
      summary_location: location,
      summary_timeframe: timeframe,
      summary_recurrence: recurrence,
      due_to_cause: due_to_cause
    )
  end

  # ===========================================================================
  # All Clear
  # ===========================================================================

  # All clear with multiple active alerts and closure effect
  def all_clear(%{effect: effect}, true, location)
      when effect in [:dock_closure, :station_closure, :stop_closure] do
    gettext("**Update:** %{mode} service has resumed%{summary_location}.",
      comment:
        ~s|Alert summary in the format of "Update: [Vehicle type] service has resumed[ at location].", ex "Update: [Train] service has resumed[ from Riverside to Newton Highlands]." or "Update: [Bus] service has resumed[ at Market St @ Lothrop St]."|,
      mode: vehicle_type(effect, :singular),
      summary_location: location
    )
  end

  # All clear with multiple active alerts and elevator closure effect
  def all_clear(%{effect: :elevator_closure}, true, location) do
    gettext("**Update:** %{mode} service has resumed%{summary_location}.",
      comment:
        ~s|Alert summary in the format of "Update: [Vehicle type] service has resumed[ at location].", ex "Update: [Train] service has resumed[ from Riverside to Newton Highlands]." or "Update: [Bus] service has resumed[ at Market St @ Lothrop St]."|,
      mode: gettext("Elevator", comment: "Elevator Service"),
      summary_location: location
    )
  end

  # All clear with multiple active alerts and shuttle effect
  def all_clear(
        %{effect: :shuttle, informed_entity: [%{route_type: route_type} | _rest]},
        true,
        location
      ) do
    gettext("**Update:** %{mode} service has resumed%{summary_location}.",
      comment:
        ~s|Alert summary in the format of "Update: [Vehicle type] service has resumed[ at location].", ex "Update: [Train] service has resumed[ from Riverside to Newton Highlands]." or "Update: [Bus] service has resumed[ at Market St @ Lothrop St]."|,
      mode: PresentationStrings.route_type(route_type, :singular, :sentence_case),
      summary_location: location
    )
  end

  # All clear with multiple active alerts
  def all_clear(%{effect: effect}, true, location) do
    gettext("**Update:** %{effect_sentence_case} has ended%{summary_location}.",
      comment:
        ~S|Alert summary in the format of "Update: [Alert effect] has ended[ at location].", ex "[Update][Stop closure] has ended[ at Haymarket]." or \"[Update][Service suspension] has ended[ from Alewife to Harvard]”.|,
      effect_sentence_case: PresentationStrings.effect(effect),
      summary_location: location
    )
  end

  # All clear with no other active alerts
  def all_clear(_alert, _has_multiple_active_alerts, _location) do
    gettext("**All clear:** Normal service has resumed.",
      comment: ~S|Alert summary in the format of \"All clear: Normal service has resumed.\"|
    )
  end

  @spec trip_specific(
          String.t(),
          Alert.t(),
          [String.t()] | nil,
          String.t(),
          String.t(),
          boolean()
        ) :: String.t()
  def trip_specific(
        trip_identity,
        %Alert{effect: :cancellation} = alert,
        _stops,
        timeframe,
        recurrence,
        multiple_trips?
      ) do
    cause = TemplateFragments.due_to_cause(alert.cause)

    if multiple_trips? do
      gettext("%{trip_identity} are cancelled %{timeframe}%{cause}%{recurrence}",
        comment: [
          "Assemble a summary of an alert with the structure:",
          "[These trips] are cancelled [today][ due to maintenance][ daily until friday]"
        ],
        trip_identity: trip_identity,
        timeframe: timeframe,
        cause: cause,
        recurrence: recurrence
      )
    else
      gettext("%{trip_identity} is cancelled %{timeframe}%{cause}%{recurrence}",
        comment: [
          "Assemble a summary of an alert with the structure:",
          "[This trip] is cancelled [today][ due to maintenance][ daily until friday]"
        ],
        trip_identity: trip_identity,
        timeframe: timeframe,
        cause: cause,
        recurrence: recurrence
      )
    end
  end

  def trip_specific(
        trip_identity,
        %Alert{effect: effect} = alert,
        stops,
        timeframe,
        recurrence,
        _one_trip?
      )
      when effect in [:dock_closure, :station_closure, :stop_closure] and stops != nil and
             stops != [] do
    gettext("%{trip_identity} %{skipped_effect}%{cause}%{recurrence}",
      comment: [
        "Assemble a summary of an alert with the structure:",
        "[This trip] [will not stop at  stop A][ due to maintenance][ daily until friday]",
        "Alert summary in the format of “[trip identity] [is affected][due to cause][until recurrence]”, ex “[12:13 PM from Ruggles] [is cancelled today][ due to a mechanical issue][ some days until Wednesday]” or “[Multiple trips] [are suspended today][][]”"
      ],
      trip_identity: trip_identity,
      skipped_effect:
        effect
        |> TemplateFragments.location(stops)
        |> TemplateFragments.skipped_effect(timeframe),
      cause: TemplateFragments.due_to_cause(alert.cause),
      recurrence: recurrence
    )
  end

  def trip_specific(
        trip_identity,
        %Alert{effect: :suspension} = alert,
        [terminating_stop | _rest],
        timeframe,
        recurrence,
        _multiple_trips?
      ) do
    gettext(
      "%{trip_identity} will terminate at %{terminating_stop} %{timeframe}%{cause}%{recurrence}",
      comment: [
        "Assemble a summary of an alert with the structure:",
        "[This trip] will terminate at [Porter][ today][ due to maintenance][ daily until friday]"
      ],
      trip_identity: trip_identity,
      terminating_stop: terminating_stop,
      timeframe: timeframe,
      cause: TemplateFragments.due_to_cause(alert.cause),
      recurrence: recurrence
    )
  end

  def trip_specific(
        trip_identity,
        %Alert{effect: :suspension} = alert,
        _stops,
        timeframe,
        recurrence,
        multiple_trips?
      ) do
    cause = TemplateFragments.due_to_cause(alert.cause)

    if multiple_trips? do
      gettext("%{trip_identity} are suspended %{timeframe}%{cause}%{recurrence}",
        comment: [
          "Assemble a summary of an alert with the structure:",
          "[These trips] are suspended [today][ due to maintenance][ daily until friday]"
        ],
        trip_identity: trip_identity,
        timeframe: timeframe,
        cause: cause,
        recurrence: recurrence
      )
    else
      gettext("%{trip_identity} is suspended %{timeframe}%{cause}%{recurrence}",
        comment: [
          "Assemble a summary of an alert with the structure:",
          "[This trip] is suspended [today][ due to maintenance][ daily until friday]"
        ],
        trip_identity: trip_identity,
        timeframe: timeframe,
        cause: cause,
        recurrence: recurrence
      )
    end
  end

  def trip_specific(
        trip_identity,
        %Alert{effect: :delay} = alert,
        _stops,
        timeframe,
        recurrence,
        _multiple_trips?
      ) do
    gettext(
      "%{trip_identity} experiencing delays%{delay_duration} %{timeframe}%{cause}%{recurrence}",
      comment: [
        "Assemble a summary of an alert with the structure:",
        "[Trip 101] experiencing delays[ of about 10 minutes][ today][ due to maintenance][ daily until Friday]"
      ],
      trip_identity: trip_identity,
      delay_duration: TemplateFragments.delay_duration(alert.severity),
      timeframe: timeframe,
      cause: TemplateFragments.due_to_cause(alert.cause),
      recurrence: recurrence
    )
  end

  def trip_specific(
        trip_identity,
        %Alert{effect: effect, cause: cause},
        _location,
        timeframe,
        recurrence,
        _multiple_trips?
      ) do
    gettext("%{trip_identity} affected by %{effect} %{timeframe}%{cause}%{recurrence}",
      comment: [
        "Assemble a summary of an alert with the structure:",
        "[This trip] affected by [detour] [today][ due to maintenance][ daily until friday]"
      ],
      trip_identity: trip_identity,
      effect: PresentationStrings.effect_sentence_case(effect),
      timeframe: timeframe,
      cause: TemplateFragments.due_to_cause(cause),
      recurrence: recurrence
    )
  end

  def trip_shuttle(trip_identity, start_stop, end_stop, recurrence, one_trip?) do
    if one_trip? do
      gettext(
        "%{trip_identity} is replaced by shuttle buses from **%{start_stop}** to **%{end_stop}**%{recurrence}",
        comment:
          "Alert summary in the format of “[trip identity] is replaced by shuttle buses from [stop] to [stop][until recurrence]”, ex “Shuttle buses replace [the 12:13 PM train] from [Ruggles] to [Forest Hills][ some days until Friday]”",
        trip_identity: trip_identity,
        start_stop: start_stop,
        end_stop: end_stop,
        recurrence: recurrence
      )
    else
      gettext(
        "Shuttle buses replace %{trip_identity} from **%{start_stop}** to **%{end_stop}**%{recurrence}",
        comment:
          "Alert summary in the format of “Shuttle buses replace [trip identity] from [stop] to [stop][until recurrence]”, ex “Shuttle buses replace [this train] from [Ruggles] to [Forest Hills][ some days until Friday]”",
        trip_identity: trip_identity,
        start_stop: start_stop,
        end_stop: end_stop,
        recurrence: recurrence
      )
    end
  end

  @spec vehicle_type(Alert.effect(), :singular | :plural) :: String.t()
  defp vehicle_type(effect, plurality) do
    case effect do
      :dock_closure ->
        PresentationStrings.route_type(:ferry, plurality, :sentence_case)

      :station_closure ->
        PresentationStrings.route_type(:light_rail, plurality, :sentence_case)

      :stop_closure ->
        PresentationStrings.route_type(:bus, plurality, :sentence_case)
    end
  end
end

defmodule MobileAppBackend.Alerts.AlertSummary do
  require Logger
  alias MBTAV3API.Alert
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop

  alias MobileAppBackend.Alerts.AlertSummary.{
    Direction,
    LineDigraph,
    Location,
    Recurrence,
    Timeframe,
    TripShuttle,
    TripSpecific
  }

  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.Subscription
  alias Util.PolymorphicJson

  @gl_label "Green Line"
  @gl_routes ~w(Green-B Green-C Green-D Green-E)

  defmodule Standard do
    alias MobileAppBackend.Alerts.AlertSummary

    @type t :: %__MODULE__{
            effect: Alert.effect(),
            location: Location.t() | nil,
            timeframe: Timeframe.t() | nil,
            recurrence: Recurrence.t() | nil,
            context: AlertSummary.context()
          }
    @derive PolymorphicJson
    defstruct [:effect, :location, :timeframe, :recurrence, :context]
  end

  defmodule AllClear do
    @type t :: %__MODULE__{
            effect: Alert.effect(),
            has_multiple_active_alerts: boolean(),
            location: Location.t() | nil
          }
    @derive PolymorphicJson
    defstruct [:effect, :has_multiple_active_alerts, :location]
  end

  defmodule Unknown do
    @type t :: %__MODULE__{fallback: String.t()}
    @derive PolymorphicJson
    defstruct [:fallback]
  end

  @type t :: Standard.t() | AllClear.t() | TripSpecific.t() | TripShuttle.t()

  @type context :: :notification | :card

  def summarizing(
        alert,
        %Subscription{stop_id: stop_id, direction_id: direction_id},
        patterns,
        at_time,
        schedules,
        global,
        context,
        has_multiple_active_alerts \\ false
      ) do
    cond do
      all_clear =
          all_clear_summary(
            alert,
            stop_id,
            direction_id,
            patterns,
            has_multiple_active_alerts,
            global
          ) ->
        all_clear

      trip_specific =
          TripSpecific.summary(
            alert,
            stop_id,
            direction_id,
            patterns,
            at_time,
            schedules,
            global,
            context
          ) ->
        trip_specific

      true ->
        recurrence = alert_recurrence(alert, at_time)

        %Standard{
          effect: alert.effect,
          location: alert_location(alert, stop_id, direction_id, patterns, global),
          timeframe: alert_timeframe(alert, at_time, not is_nil(recurrence)),
          recurrence: recurrence,
          context: context
        }
    end
  end

  @doc """
  Combines multiple different summaries of an alert produced by different subscriptions
  into a single summary. When possible, picks a descriptive location and timeframe that
  applies to all summaries. If not possible, those fields are nil in the result.
  """
  @spec combine_summaries(Alert.t(), [t()]) :: t()

  def combine_summaries(_alert, [summary]), do: summary

  def combine_summaries(alert, summaries) do
    effect = alert.effect

    summaries = Enum.uniq(summaries)

    cond do
      Enum.count(summaries) == 1 ->
        List.first(summaries)

      Enum.all?(summaries, &match?(%__MODULE__.AllClear{}, &1)) ->
        location =
          summaries
          |> Enum.map(& &1.location)
          |> Enum.uniq()
          |> deduplicate_locations()

        %__MODULE__.AllClear{
          effect: effect,
          has_multiple_active_alerts: summaries |> Enum.any?(& &1.has_multiple_active_alerts),
          location: location
        }

      Enum.all?(summaries, &match?(%__MODULE__.Standard{}, &1)) ->
        location =
          summaries
          |> Enum.map(& &1.location)
          |> Enum.uniq()
          |> deduplicate_locations()

        timeframe =
          summaries
          |> Enum.map(& &1.timeframe)
          |> Enum.uniq()
          |> case do
            # Timeframe should always be the same since it is a property of the alert
            # itself, not something that is based on the subscription.
            [timeframe] -> timeframe
            _ -> nil
          end

        %__MODULE__.Standard{effect: effect, location: location, timeframe: timeframe}

      Enum.all?(summaries, fn summary ->
        %type{} = summary
        match?(TripShuttle, type)
      end) ->
        __MODULE__.TripShuttle.combine(alert, summaries)

      Enum.all?(summaries, fn summary ->
        %type{} = summary
        match?(TripSpecific, type)
      end) ->
        __MODULE__.TripSpecific.combine(alert, summaries)

      true ->
        %__MODULE__.Standard{effect: alert.effect}
    end
  end

  defp deduplicate_locations(locations) do
    case locations do
      [location] ->
        location

      [
        %__MODULE__.Location.SuccessiveStops{start_stop_name: s1, end_stop_name: s2},
        %__MODULE__.Location.SuccessiveStops{start_stop_name: s2, end_stop_name: s1}
      ] ->
        [s1, s2] = Enum.sort([s1, s2])
        %__MODULE__.Location.SuccessiveStops{start_stop_name: s1, end_stop_name: s2}

      [
        %__MODULE__.Location.StopToDirection{start_stop_name: stop, direction: direction} =
            location,
        %__MODULE__.Location.DirectionToStop{
          direction: opposite_direction,
          end_stop_name: stop
        }
      ]
      when opposite_direction.id == 1 - direction.id ->
        location

      [
        %__MODULE__.Location.AffectedStops{stops: stop_list_1} = location,
        %__MODULE__.Location.AffectedStops{stops: stop_list_2}
      ] ->
        if Enum.sort(stop_list_1) == Enum.sort(stop_list_2) do
          location
        else
          nil
        end

      _ ->
        nil
    end
  end

  @spec all_clear_summary(
          Alert.t(),
          Stop.id(),
          0 | 1,
          [RoutePattern.t()],
          boolean(),
          GlobalDataCache.data()
        ) :: AllClear.t() | nil
  defp all_clear_summary(
         alert,
         stop_id,
         direction_id,
         patterns,
         has_multiple_active_alerts,
         global
       ) do
    if Alert.all_clear?(alert) do
      %AllClear{
        effect: alert.effect,
        has_multiple_active_alerts: has_multiple_active_alerts,
        location: alert_location(alert, stop_id, direction_id, patterns, global)
      }
    end
  end

  defp alert_location_is_closure?(alert, affected_stops) do
    alert.effect in [:dock_closure, :station_closure, :stop_closure, :parking_closure] and
      affected_stops != [] and (Alert.active?(alert) or Alert.active_soon?(alert))
  end

  @spec alert_location(Alert.t(), Stop.id(), 0 | 1, [RoutePattern.t()], GlobalDataCache.data()) ::
          Location.t() | nil

  def alert_location(alert, stop_id, direction_id, [], _global) do
    # Seen on ferry patterns, no patterns match provided becuase they are all in the same direction
    Logger.notice(
      "#{__MODULE__}: No patterns match for alert: #{inspect(alert)} at stop: #{stop_id} with direction: #{direction_id}"
    )

    nil
  end

  def alert_location(alert, stop_id, direction_id, patterns, global) do
    routes = routes_for_patterns(patterns, global)

    with nil <- alert_location_for_whole_gl(alert, routes, patterns, direction_id, global),
         nil <- alert_location_for_whole_route(alert, direction_id, routes) do
      affected_stops = get_alert_affected_stops(global, alert, routes)
      downstream = Enum.all?(affected_stops, &(&1.id != stop_id))

      cond do
        alert_location_is_closure?(alert, affected_stops) ->
          %Location.AffectedStops{
            stops: Enum.map(affected_stops, fn stop -> stop.name end)
          }

        length(affected_stops) == 1 ->
          %Location.SingleStop{stop_name: hd(affected_stops).name, downstream: downstream}

        # Never show multiple stops for bus
        Enum.any?(routes, &(&1.type == :bus and not String.starts_with?(&1.id, "Shuttle"))) ->
          nil

        true ->
          alert_location_for_multiple_stops(
            alert,
            stop_id,
            direction_id,
            patterns,
            routes,
            downstream,
            global
          )
      end
    else
      location -> location
    end
  end

  @spec alert_timeframe(Alert.t(), DateTime.t(), boolean()) ::
          Timeframe.t() | nil
  defp alert_timeframe(alert, at_time, has_recurrence?)

  defp alert_timeframe(%Alert{duration_certainty: :estimated}, _, _),
    do: %Timeframe.LaterToday{}

  defp alert_timeframe(alert, at_time, has_recurrence?) do
    service_date = Util.DateTime.datetime_to_gtfs(at_time)

    case Alert.current_period(alert, at_time) do
      %Alert.ActivePeriod{end: nil} ->
        %Timeframe.UntilFurtherNotice{}

      %Alert.ActivePeriod{} = current_period ->
        if has_recurrence? do
          alert_timeframe_range(current_period)
        else
          alert_timeframe_current(service_date, current_period)
        end

      nil ->
        case Alert.next_period(alert, at_time) do
          %Alert.ActivePeriod{} = next_period ->
            alert_timeframe_upcoming(service_date, next_period)

          nil ->
            nil
        end
    end
  end

  defp alert_timeframe_range(%Alert.ActivePeriod{} = ap) do
    start_time =
      if DateTime.to_time(ap.start) == ~T[03:00:00] do
        %Timeframe.TimeRange.StartOfService{}
      else
        %Timeframe.TimeRange.Time{time: ap.start}
      end

    end_time =
      if Alert.ActivePeriod.to_end_of_service?(ap) do
        %Timeframe.TimeRange.EndOfService{}
      else
        %Timeframe.TimeRange.Time{time: ap.end}
      end

    %Timeframe.TimeRange{start_time: start_time, end_time: end_time}
  end

  defp alert_timeframe_current(service_date, %Alert.ActivePeriod{end: end_time} = current_period) do
    end_date = Util.DateTime.datetime_to_gtfs(end_time, rounding: :backwards)

    cond do
      service_date == end_date and Alert.ActivePeriod.to_end_of_service?(current_period) ->
        %Timeframe.EndOfService{}

      service_date == end_date ->
        %Timeframe.Time{time: end_time}

      Date.add(service_date, 1) == end_date ->
        %Timeframe.Tomorrow{}

      later_this_week(service_date, end_date) ->
        %Timeframe.ThisWeek{time: end_time}

      true ->
        %Timeframe.LaterDate{time: end_time}
    end
  end

  defp alert_timeframe_upcoming(service_date, %Alert.ActivePeriod{start: start_time}) do
    start_service_date = Util.DateTime.datetime_to_gtfs(start_time)

    if start_service_date == service_date do
      %Timeframe.StartingLaterToday{time: start_time}
    else
      %Timeframe.StartingTomorrow{}
    end
  end

  @spec alert_recurrence(Alert.t(), DateTime.t()) :: Recurrence.t() | nil
  def alert_recurrence(alert, at_time) do
    with %Alert.RecurrenceInfo{end: last_period_end} = range <- Alert.recurrence_range(alert),
         service_date = Util.DateTime.datetime_to_gtfs(at_time),
         last_service_date when last_service_date != service_date <-
           Util.DateTime.datetime_to_gtfs(last_period_end, rounding: :backwards) do
      ending =
        cond do
          !range.end_day_known ->
            %Timeframe.UntilFurtherNotice{}

          Date.add(service_date, 1) == last_service_date ->
            %Timeframe.Tomorrow{}

          later_this_week(service_date, last_service_date) ->
            %Timeframe.ThisWeek{time: last_period_end}

          true ->
            %Timeframe.LaterDate{time: last_period_end}
        end

      if Alert.RecurrenceInfo.daily(range) do
        %Recurrence.Daily{ending: ending}
      else
        %Recurrence.SomeDays{ending: ending}
      end
    else
      _ -> nil
    end
  end

  defp get_alert_affected_stops(global, alert, routes) do
    route_entities =
      Enum.flat_map(routes, fn route ->
        alert.informed_entity
        |> Enum.filter(fn entity ->
          Alert.InformedEntity.route?(entity, route.id)
        end)
      end)

    route_entities
    |> Enum.map(&Stop.parent_if_exists(global.stops[&1.stop], global.stops))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp alert_applies_to_whole_gl_route(alert, route_id, direction_id, global) do
    if route_id not in @gl_routes do
      raise "alert_applies_to_whole_gl_route should never be called for a non-GL route"
    end

    if matches_whole_route(alert, route_id, direction_id) do
      true
    else
      gl_route = global.routes[route_id]

      if is_nil(gl_route) do
        false
      else
        gl_patterns =
          global.route_patterns
          |> Map.values()
          |> Enum.filter(&(&1.typicality == :typical and &1.route_id == route_id))

        # The blank stop ID is fine because the ID is only used to check if the stop is on a GL branch,
        # and here we specifically don't care about branching
        affected_pattern_stops =
          affected_pattern_stops(gl_patterns, alert, global)
          |> discard_subsets()

        matches_all_stops_on_patterns(affected_pattern_stops, global)
      end
    end
  end

  defp alert_location_for_multiple_stops(
         alert,
         stop_id,
         direction_id,
         patterns,
         routes,
         downstream,
         global
       ) do
    aumented_patterns =
      augment_patterns_for_branched_lines(routes, direction_id, patterns, global)

    affected_pattern_stops = affected_pattern_stops(aumented_patterns, alert, global)

    matches_all_stops = matches_all_stops_on_patterns(affected_pattern_stops, global)

    case routes do
      [single_route] when matches_all_stops ->
        %Location.WholeRoute{
          route_label: Route.label(single_route),
          route_type: single_route.type
        }

      _ ->
        build_location_for_multiple_stops(
          aumented_patterns,
          affected_pattern_stops,
          stop_id,
          direction_id,
          downstream,
          global,
          alert,
          patterns
        )
    end
  end

  @spec build_location_for_multiple_stops(
          aumented_patterns :: [RoutePattern.t()],
          affected_pattern_stops :: %{RoutePattern.t() => [String.t()]},
          stop_id :: String.t() | nil,
          direction_id :: 0 | 1,
          downstream :: boolean(),
          global :: GlobalDataCache.data(),
          alert :: Alert.t(),
          patterns :: [RoutePattern.t()]
        ) :: Location.t() | nil
  defp build_location_for_multiple_stops(
         aumented_patterns,
         affected_pattern_stops,
         stop_id,
         direction_id,
         downstream,
         global,
         alert,
         patterns
       ) do
    digraph =
      LineDigraph.build_stops_digraph_from_patterns(aumented_patterns, direction_id, global)

    with :ok <- LineDigraph.remove_unreachable_stops_from_digraph(digraph, stop_id),
         :ok <- LineDigraph.remove_unaffected_stops(digraph, affected_pattern_stops) do
      build_location_from_affected_stops_digraph(
        digraph,
        patterns,
        direction_id,
        downstream,
        global,
        alert
      )
    else
      {:error, :stop_not_found} ->
        Logger.warning(
          "#{__MODULE__} stop: #{stop_id} not found on route patterns: #{Enum.map_join(patterns, ", ", & &1.id)}"
        )

        nil

      {:error, :disconnected_stops} ->
        if alert.effect == :suspension or alert.effect == :shuttle do
          # Logging this message so we check the alert for potential data issues
          Logger.warning(
            "#{__MODULE__} Build location for alert: #{alert.id} has disconnected stops, this could be a data issue"
          )
        end

        stops = affected_pattern_stops |> Enum.flat_map(fn {_pattern, stops} -> stops end)

        %Location.AffectedStops{
          stops: stops
        }
    end
  end

  defp alert_location_for_whole_gl(alert, routes, patterns, direction_id, global) do
    typical_routes =
      patterns
      |> Enum.filter(&(&1.typicality == :typical))
      |> routes_for_patterns(global)

    is_gl =
      typical_routes != [] and
        Enum.all?(typical_routes, &(&1.id in @gl_routes))

    if is_gl do
      affected_branches =
        Enum.filter(@gl_routes, fn route_id ->
          alert_applies_to_whole_gl_route(alert, route_id, direction_id, global)
        end)

      route = Enum.find(routes, &(&1.id in affected_branches))

      cond do
        Enum.sort(affected_branches) == Enum.sort(@gl_routes) ->
          %Location.WholeRoute{route_label: @gl_label, route_type: :light_rail}

        length(affected_branches) == 1 and route != nil ->
          %Location.WholeRoute{route_label: Route.label(route), route_type: :light_rail}

        true ->
          nil
      end
    else
      nil
    end
  end

  defp alert_location_for_whole_route(alert, direction_id, routes) do
    case routes do
      [single_route] ->
        if matches_whole_route(alert, single_route.id, direction_id) do
          %Location.WholeRoute{
            route_label: Route.label(single_route),
            route_type: single_route.type
          }
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp matches_all_stops_on_patterns(pattern_stops, global) do
    map_size(pattern_stops) > 0 and
      Enum.all?(pattern_stops, fn {pattern, affected_stops} ->
        matches_all_stops_on_trip(
          global.trips[pattern.representative_trip_id],
          affected_stops,
          global
        )
      end)
  end

  defp matches_all_stops_on_trip(nil, _, _), do: false

  defp matches_all_stops_on_trip(trip, affected_stops, global),
    do:
      Enum.all?(trip.stop_ids, fn stop_id ->
        parent = Stop.parent_id(global.stops[stop_id])
        parent in affected_stops
      end)

  defp matches_whole_route(alert, route_id, direction_id) do
    Alert.any_informed_entity_satisfies(alert, fn entity ->
      Alert.InformedEntity.direction?(entity, direction_id) and
        Alert.InformedEntity.route?(entity, route_id) and
        is_nil(entity.trip) and is_nil(entity.stop) and is_nil(entity.facility)
    end)
  end

  defp routes_for_patterns(patterns, global) do
    patterns
    |> Enum.uniq_by(& &1.route_id)
    |> Enum.map(&global.routes[&1.route_id])
    |> Enum.reject(&is_nil/1)
  end

  defp later_this_week(on_date, end_date) do
    Date.day_of_week(on_date) < Date.day_of_week(end_date) and Date.diff(end_date, on_date) < 7
  end

  defp discard_subsets(pattern_stops) do
    Map.filter(pattern_stops, fn {this_pattern, these_stops} ->
      not Enum.any?(pattern_stops, fn {other_pattern, other_stops} ->
        other_pattern != this_pattern and length(other_stops) > length(these_stops) and
          Enum.all?(these_stops, &(&1 in other_stops))
      end)
    end)
  end

  # Augments the given list of route patterns for branched lines, such as the Green Line.
  # If all routes are part of the Green Line, it will include all patterns for the specified direction.
  # Otherwise, it returns the original list of patterns.
  # Note: This is not needed for the red line because the red line provides all the relevant patterns already.
  @spec augment_patterns_for_branched_lines(
          [Route.t()],
          1 | 0,
          [RoutePattern.t()],
          GlobalDataCache.data()
        ) :: [RoutePattern.t()]
  defp augment_patterns_for_branched_lines(routes, direction_id, patterns, global) do
    cond do
      routes == [] ->
        patterns

      Enum.all?(routes, &(&1.id in @gl_routes)) ->
        global.route_patterns
        |> Map.values()
        |> Enum.filter(&(&1.route_id in @gl_routes and &1.direction_id == direction_id))

      true ->
        patterns
    end
  end

  @spec affected_pattern_stops([RoutePattern.t()], Alert.t(), GlobalDataCache.data()) :: %{
          RoutePattern.t() => [String.t()]
        }
  defp affected_pattern_stops(patterns, alert, global) do
    patterns
    |> Enum.map(&{&1, affected_parent_stops_for_pattern(&1, alert, global)})
    |> Map.new()
  end

  @spec affected_parent_stops_for_pattern(RoutePattern.t(), Alert.t(), GlobalDataCache.data()) ::
          [String.t()]
  defp affected_parent_stops_for_pattern(pattern, alert, global) do
    affected_child_stops_for_pattern(pattern, alert, global)
    |> Stop.get_parent_ids(global)
  end

  @spec affected_child_stops_for_pattern(RoutePattern.t(), Alert.t(), GlobalDataCache.data()) :: [
          String.t()
        ]
  defp affected_child_stops_for_pattern(pattern, alert, global) do
    RoutePattern.get_child_stop_ids(pattern, global)
    |> Enum.filter(fn stop_on_trip ->
      Alert.any_informed_entity_satisfies(
        alert,
        &(Alert.InformedEntity.stop_in?(&1, [stop_on_trip]) and
            Alert.InformedEntity.route?(&1, pattern.route_id))
      )
    end)
  end

  @spec build_location_from_affected_stops_digraph(
          :digraph.graph(),
          [RoutePattern.t()],
          0 | 1,
          boolean(),
          GlobalDataCache.data(),
          Alert.t()
        ) :: Location.t() | nil
  defp build_location_from_affected_stops_digraph(
         digraph,
         patterns,
         direction_id,
         downstream,
         global,
         alert
       ) do
    first_stops = LineDigraph.get_first_stops(digraph, global)
    last_stops = LineDigraph.get_last_stops(digraph, global)

    %{
      first_stops: first_stops,
      last_stops: last_stops
    }
    |> case do
      %{first_stops: [first_stop], last_stops: [last_stop]} ->
        %Location.SuccessiveStops{
          start_stop_name: first_stop.name,
          end_stop_name: last_stop.name,
          downstream: downstream
        }

      %{first_stops: [first_stop], last_stops: _last_stops} ->
        directions =
          Direction.get_directions_for_line(global, first_stop, patterns)

        %Location.StopToDirection{
          start_stop_name: first_stop.name,
          direction: Enum.at(directions, direction_id),
          downstream: downstream
        }

      %{first_stops: _first_stops, last_stops: [last_stop]} ->
        directions =
          Direction.get_directions_for_line(global, last_stop, patterns)

        %Location.DirectionToStop{
          direction: Enum.at(directions, 1 - direction_id),
          end_stop_name: last_stop.name,
          downstream: downstream
        }

      _ ->
        Logger.warning(
          "#{__MODULE__} Location couldn't be determined for alert [#{alert.id}] and digraph with " <>
            "first stops [#{Enum.map_join(first_stops, ", ", & &1.id)}] and " <>
            "last stops [#{Enum.map_join(last_stops, ", ", & &1.id)}]"
        )

        nil
    end
  end
end

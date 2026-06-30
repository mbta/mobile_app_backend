defmodule MobileAppBackend.Alerts.AlertSummary do
  alias MBTAV3API.Alert
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Schedule
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip

  alias MobileAppBackend.Alerts.AlertSummary.{
    Direction,
    Location,
    Recurrence,
    Timeframe,
    TripShuttle,
    TripSpecific
  }

  alias MobileAppBackend.GlobalDataCache
  alias Util.PolymorphicJson

  @gl_id "line-Green"
  @gl_label "Green Line"
  @gl_routes ~w(Green-B Green-C Green-D Green-E)

  defmodule Standard do
    @type t :: %__MODULE__{
            effect: Alert.effect(),
            location: Location.t() | nil,
            timeframe: Timeframe.t() | nil,
            recurrence: Recurrence.t() | nil,
            is_update: boolean()
          }
    @derive PolymorphicJson
    defstruct [:effect, :location, :timeframe, :recurrence, :is_update]
  end

  defmodule AllClear do
    @type t :: %__MODULE__{location: Location.t() | nil}
    @derive PolymorphicJson
    defstruct [:location]
  end

  defmodule Unknown do
    @type t :: %__MODULE__{fallback: String.t()}
    @derive PolymorphicJson
    defstruct [:fallback]
  end

  @type t :: Standard.t() | AllClear.t() | TripSpecific.t() | TripShuttle.t()

  @type context :: :notification | :card

  @spec summarizing(
          Alert.t(),
          Stop.id(),
          0 | 1,
          [RoutePattern.t()],
          DateTime.t(),
          [Schedule.t()] | nil,
          GlobalDataCache.data(),
          context()
        ) :: t()
  def summarizing(alert, stop_id, direction_id, patterns, at_time, schedules, global, context) do
    with nil <- all_clear_summary(alert, stop_id, direction_id, patterns, global),
         nil <-
           TripSpecific.summary(
             alert,
             stop_id,
             direction_id,
             patterns,
             at_time,
             schedules,
             global,
             context
           ) do
      recurrence = alert_recurrence(alert, at_time)

      %Standard{
        effect: alert.effect,
        location: alert_location(alert, stop_id, direction_id, patterns, global),
        timeframe: alert_timeframe(alert, at_time, not is_nil(recurrence)),
        recurrence: recurrence,
        is_update: alert_is_update?(alert, at_time)
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

        %__MODULE__.AllClear{location: location}

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

      _ ->
        nil
    end
  end

  @spec all_clear_summary(
          Alert.t(),
          Stop.id(),
          0 | 1,
          [RoutePattern.t()],
          GlobalDataCache.data()
        ) :: AllClear.t() | nil
  defp all_clear_summary(alert, stop_id, direction_id, patterns, global) do
    if Alert.all_clear?(alert) do
      %AllClear{location: alert_location(alert, stop_id, direction_id, patterns, global)}
    end
  end

  defp alert_location_closure(alert, affected_stops) do
    alert.effect in [:station_closure, :stop_closure] and
      affected_stops != [] and Alert.active?(alert)
  end

  @spec alert_location(Alert.t(), Stop.id(), 0 | 1, [RoutePattern.t()], GlobalDataCache.data()) ::
          Location.t() | nil
  def alert_location(alert, stop_id, direction_id, patterns, global) do
    routes = routes_for_patterns(patterns, global)

    typical_routes =
      patterns
      |> Enum.filter(&(&1.typicality == :typical))
      |> routes_for_patterns(global)

    is_gl =
      typical_routes != [] and
        Enum.all?(typical_routes, &(&1.id in @gl_routes))

    # If the route is on the GL, check if the alert applies to the entirety of every
    # branch or an entire single branch (not necessarily a provided branch)
    gl_whole_route_location =
      if is_gl do
        alert_location_for_whole_gl(alert, direction_id, global)
      else
        nil
      end

    with nil <- gl_whole_route_location,
         nil <- alert_location_for_whole_route(alert, direction_id, routes) do
      affected_stops = get_alert_affected_stops(global, alert, routes)
      downstream = Enum.all?(affected_stops, &(&1.id != stop_id))

      cond do
        alert_location_closure(alert, affected_stops) ->
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

  defp alert_timeframe(%Alert{duration_certainty: :estimated}, _, _), do: nil

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

  @spec alert_is_update?(Alert.t(), DateTime.t()) :: boolean()
  defp alert_is_update?(alert, at_time) do
    case Alert.current_period(alert, at_time) do
      %Alert.ActivePeriod{start: start_time}
      when not is_nil(alert.updated_at) ->
        updated_after_active = DateTime.compare(start_time, alert.updated_at) == :lt
        five_minutes_ago = DateTime.add(at_time, -5, :minute)

        updated_within_five_minutes =
          DateTime.compare(alert.updated_at, five_minutes_ago) == :gt

        updated_after_active and updated_within_five_minutes

      _ ->
        false
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
          map_patterns_to_affected_stops(alert, "", direction_id, gl_patterns, [gl_route], global)

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
    # Map each pattern to its list of stops affected by this alert
    affected_pattern_stops =
      map_patterns_to_affected_stops(
        alert,
        stop_id,
        direction_id,
        patterns,
        routes,
        global
      )

    # If every affected stop on the patterns are specified in the informed entities,
    # return the whole route location
    matches_all_stops = matches_all_stops_on_patterns(affected_pattern_stops, global)

    case routes do
      [single_route] when matches_all_stops ->
        %Location.WholeRoute{
          route_label: Route.label(single_route),
          route_type: single_route.type
        }

      _ ->
        multi_stop_location(affected_pattern_stops, direction_id, downstream, global)
    end
  end

  defp alert_location_for_whole_gl(alert, direction_id, global) do
    affected_branches =
      Enum.filter(@gl_routes, fn route_id ->
        alert_applies_to_whole_gl_route(alert, route_id, direction_id, global)
      end)

    cond do
      Enum.sort(affected_branches) == Enum.sort(@gl_routes) ->
        %Location.WholeRoute{route_label: @gl_label, route_type: :light_rail}

      length(affected_branches) == 1 ->
        route = global.routes[hd(affected_branches)]

        if route,
          do: %Location.WholeRoute{route_label: Route.label(route), route_type: route.type},
          else: nil

      true ->
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

  defp multi_stop_location(affected_pattern_stops, direction_id, downstream, global) do
    # Compare the first stop list to all the others to determine if all patterns share the same disrupted stops,
    # or if multiple branches are disrupted
    first_stops = affected_pattern_stops |> Map.values() |> Enum.find(&(length(&1) > 1))
    ordered_stops = if first_stops, do: first_stops |> Enum.map(&global.stops[&1])

    cond do
      is_nil(first_stops) ->
        nil

      Enum.all?(affected_pattern_stops, fn {_, stops} ->
        MapSet.equal?(MapSet.new(stops), MapSet.new(first_stops))
      end) ->
        %Location.SuccessiveStops{
          start_stop_name: List.first(ordered_stops).name,
          end_stop_name: List.last(ordered_stops).name,
          downstream: downstream
        }

      Enum.all?(affected_pattern_stops, fn {_, stops} ->
        List.first(stops) == List.first(ordered_stops).id
      end) ->
        stop = List.first(ordered_stops)

        directions =
          Direction.get_directions_for_line(
            global,
            stop,
            Map.keys(affected_pattern_stops)
          )

        %Location.StopToDirection{
          start_stop_name: stop.name,
          direction: Enum.at(directions, direction_id),
          downstream: downstream
        }

      Enum.all?(affected_pattern_stops, fn {_, stops} ->
        List.last(stops) == List.last(ordered_stops).id
      end) ->
        stop = List.last(ordered_stops)

        directions =
          Direction.get_directions_for_line(
            global,
            stop,
            Map.keys(affected_pattern_stops)
          )

        %Location.DirectionToStop{
          direction: Enum.at(directions, 1 - direction_id),
          end_stop_name: stop.name,
          downstream: downstream
        }

      true ->
        nil
    end
  end

  defp routes_for_patterns(patterns, global) do
    patterns
    |> Enum.uniq_by(& &1.route_id)
    |> Enum.map(&global.routes[&1.route_id])
    |> Enum.reject(&is_nil/1)
  end

  # The first value in these pairs is the list of trunk stops for each route, including a few minor child stop
  # differences at some stops, like Park and Kenmore. Stops on branches on the opposite end of the line are not
  # included, only trunk stops are included. The second value contains all the child stops that exist only on each
  # branch. These are hard coded because the patterns provided to `summarizing` will only include ones served at the
  # selected stop, they don't take other branches into account, but we always want to show when a disruption is
  # happening on all downstream branches.
  @westbound_branches [
    # B Branch
    {
      [
        # Lechmere
        "70502",
        "70208",
        "70206",
        "70204",
        "70202",
        "70196",
        "70159",
        "70157",
        "70155",
        "70153",
        # Kenmore
        "71151"
      ],
      [
        # Blandford Street
        "70149",
        "70147",
        "70145",
        "170141",
        "170137",
        "70135",
        "70131",
        "70129",
        "70127",
        "70125",
        "70121",
        "70117",
        "70115",
        "70113",
        "70111",
        # Boston College
        "70107"
      ]
    },
    # C Branch
    {
      [
        # Lechmere
        "70502",
        "70208",
        "70206",
        "70204",
        "70202",
        "70197",
        "70159",
        "70157",
        "70155",
        "70153",
        # Kenmore
        "70151"
      ],
      [
        # Saint Mary's Street
        "70211",
        "70213",
        "70215",
        "70217",
        "70219",
        "70223",
        "70225",
        "70227",
        "70229",
        "70231",
        "70233",
        "70235",
        # Cleveland Circle
        "70237"
      ]
    },
    # D Branch
    {
      [
        # Lechmere
        "70502",
        "70208",
        "70206",
        "70204",
        "70202",
        "70198",
        "70159",
        "70157",
        "70155",
        "70153",
        # Kenmore
        "70151"
      ],
      [
        # Fenway
        "70187",
        "70183",
        "70181",
        "70179",
        "70177",
        "70175",
        "70173",
        "70171",
        "70169",
        "70167",
        "70165",
        "70163",
        # Riverside
        "70161"
      ]
    },
    # E Branch
    {
      [
        # Lechmere
        "70502",
        "70208",
        "70206",
        "70204",
        "70202",
        "70199",
        "70159",
        "70157",
        # Copley
        "70155"
      ],
      [
        # Prudential
        "70239",
        "70241",
        "70243",
        "70245",
        "70247",
        "70249",
        "70251",
        "70253",
        "70255",
        "70257",
        # Heath Street
        "70260"
      ]
    }
  ]

  @eastbound_branches [
    # Medford/Tufts
    {
      [
        # Kenmore
        "70150",
        "70152",
        "70154",
        "70156",
        "70158",
        "70200",
        "70201",
        "70203",
        "70205",
        "70207",
        # Lechmere
        "70501"
      ],
      [
        # East Somerville
        "70513",
        "70505",
        "70507",
        "70509",
        # Medford/Tufts
        "70511"
      ]
    },
    # Union
    {
      [
        # Kenmore
        "70150",
        "70152",
        "70154",
        "70156",
        "70158",
        "70200",
        "70201",
        "70203",
        "70205",
        "70207",
        # Lechmere
        "70501"
      ],
      [
        # Union Square
        "70503"
      ]
    }
  ]

  defp map_patterns_to_affected_stops(alert, stop_id, direction_id, patterns, routes, global) do
    pattern_stops =
      patterns
      |> Enum.filter(&(&1.direction_id == direction_id))
      |> Enum.map(fn pattern ->
        case global.trips[pattern.representative_trip_id] do
          %Trip{} = trip -> {pattern, trip.stop_ids}
          _ -> {pattern, []}
        end
      end)
      |> Kernel.++(
        # Special casing to properly show when alerts affect multiple GL branches
        if Enum.any?(routes, &(&1.line_id == @gl_id)) do
          gl_synthetic_patterns(stop_id, direction_id, routes, global)
        else
          []
        end
      )
      |> Enum.map(fn {pattern, stop_ids} ->
        stop_ids_on_pattern =
          stop_ids
          |> Enum.filter(fn stop_on_trip ->
            Alert.any_informed_entity_satisfies(
              alert,
              &(Alert.InformedEntity.stop_in?(&1, [stop_on_trip]) and
                  Alert.InformedEntity.route?(&1, pattern.route_id))
            )
          end)
          |> Enum.map(&Stop.parent_id(global.stops[&1]))
          |> Enum.reject(&is_nil/1)

        case stop_ids_on_pattern do
          [] -> nil
          _ -> {pattern, stop_ids_on_pattern}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    # On the D branch, there are patterns that terminate at Reservoir and Riverside, this will remove stop lists that
    # are subsets of some other stop list so that we don't display "Westbound stops" instead of "Riverside" in this
    # case.
    if map_size(pattern_stops) > 1 do
      discard_subsets(pattern_stops)
    else
      pattern_stops
    end
  end

  defp later_this_week(on_date, end_date) do
    Date.day_of_week(on_date) < Date.day_of_week(end_date) and Date.diff(end_date, on_date) < 7
  end

  defp gl_synthetic_patterns(stop_id, direction_id, routes, global) do
    direction_stops =
      case direction_id do
        0 -> @westbound_branches
        1 -> @eastbound_branches
      end

    # If the provided stop is on a branch, don't take any parallel branches into account,
    # we only want to group downstream branches
    if Enum.any?(direction_stops, fn {_, branch_stops} ->
         Enum.any?(branch_stops, &(Stop.parent_id(global.stops[&1]) == stop_id))
       end) do
      []
    else
      Enum.map(direction_stops, fn {earlier, branched} ->
        {%RoutePattern{
           id: Enum.join(branched, "-"),
           direction_id: direction_id,
           name: "",
           sort_order: 0,
           typicality: :typical,
           representative_trip_id: "",
           route_id: hd(routes).id
         }, earlier ++ branched}
      end)
    end
  end

  defp discard_subsets(pattern_stops) do
    Map.filter(pattern_stops, fn {this_pattern, these_stops} ->
      not Enum.any?(pattern_stops, fn {other_pattern, other_stops} ->
        other_pattern != this_pattern and length(other_stops) > length(these_stops) and
          Enum.all?(these_stops, &(&1 in other_stops))
      end)
    end)
  end
end

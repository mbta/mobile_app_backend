defmodule MobileAppBackend.Alerts.AlertSummary do
  alias MBTAV3API.Alert
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache

  defmodule Direction do
    alias MBTAV3API.Route
    @type t :: %__MODULE__{name: String.t() | nil, destination: String.t() | nil, id: 0 | 1}
    @derive JSON.Encoder
    @derive Jason.Encoder
    defstruct [:name, :destination, :id]

    @doc """
    This constructor is used to provide additional context to a Direction to allow for overriding
    the destination label in cases where a route or line has branching. We want to display a
    different label when you're on the trunk or a branch to match station signage. First, this
    checks if any special case overrides should be applied for the provided route, stop, and
    direction (ex "Copley & West" at any GL stop upstream of the E and B/C/D fork at Copley). If
    no special case is found, fall back to an optional pattern destination, used when a pattern
    goes to an atypical destination that doesn't match the route's destination. If one of those
    isn't provided, then use the value from route.directionDestinations, which should be accurate
    in the majority of typical cases. If this doesn't exist for some reason, fall back to null so
    that the direction label will just display the direction name.
    """
    def new(
          direction_id,
          route,
          stop_id \\ nil,
          route_stop_ids \\ nil,
          pattern_destination \\ nil
        ) do
      %__MODULE__{
        name: Enum.at(route.direction_names, direction_id),
        destination:
          get_special_case_destination(
            direction_id,
            route.id,
            stop_id,
            route_stop_ids
          ) ||
            pattern_destination || Enum.at(route.direction_destinations, direction_id),
        id: direction_id
      }
    end

    # This is split into a separate variable for a hardcoded check
    @north_station_destination "North Station & North"

    # This is a map containing all the special case direction labels for branching routes.
    #
    # The top level key is the route ID (or route alias defined in idOverrides).
    # The value of the top level map is a list containing two other lists, with the index
    # corresponding to each of the direction IDs for that route. If one of these lists is null,
    # there are no special cases for that route and direction (like northbound Red line).
    #
    # The list for each direction contains a sequence of pairs of stop IDs and override labels.
    # The stop IDs are ordered as they appear along the typical route pattern for that direction.
    # Only parent stop IDs can be used, and entries are added for every label change that happens
    # as you move along the route.
    #
    # The `getSpecialCaseDestination` function will find where the provided stop ID is in relation
    # to the (id, label) pairs, and returns the first label with an ID that exists in the
    # `routeStopIds` sequence after (or equal to) the provided stop ID.
    #
    # A null value means to ignore special cases and fall back to the route's default labels.
    @special_cases %{
      "line-Green" => [
        [
          {"place-armnl", "Copley & West"},
          {"place-hymnl", "Kenmore & West"},
          {"place-prmnl", nil},
          {"place-kencl", nil}
        ],
        [
          {"place-boyls", "Park St & North"},
          {"place-pktrm", "Gov Ctr & North"},
          {"place-haecl", @north_station_destination},
          {"place-spmnl", "Lechmere & North"},
          {"place-lech", nil}
        ]
      ],
      "Red" => [
        [
          {"place-jfk", nil},
          {"place-asmnl", "Ashmont"},
          {"place-brntn", "Braintree"}
        ],
        nil
      ]
    }

    @id_overrides %{
      "Green-B" => "line-Green",
      "Green-C" => "line-Green",
      "Green-D" => "line-Green",
      "Green-E" => "line-Green"
    }

    @spec get_special_case_destination(0 | 1, Route.id(), Stop.id() | nil, [Stop.id()] | nil) ::
            String.t() | nil
    def get_special_case_destination(direction_id, route_id, stop_id, route_stop_ids) do
      with route_cases when not is_nil(route_cases) <-
             @special_cases[@id_overrides[route_id] || route_id],
           direction_cases when not is_nil(direction_cases) <- Enum.at(route_cases, direction_id),
           stops when not is_nil(stops) <- route_stop_ids,
           stop_index when not is_nil(stop_index) <- Enum.find_index(stops, &(&1 == stop_id)),
           {_, destination} <-
             Enum.find(direction_cases, fn {case_stop_id, _} ->
               case_stop_index = Enum.find_index(stops, &(&1 == case_stop_id))
               not is_nil(case_stop_index) and stop_index <= case_stop_index
             end) do
        destination
      else
        _ -> nil
      end
    end

    @spec get_directions(GlobalDataCache.data(), Stop.t(), Route.t(), [RoutePattern.t()]) :: [t()]
    def get_directions(global, stop, route, patterns) do
      if Map.has_key?(@special_cases, @id_overrides[route.id] || route.id) do
        stop_list_by_direction = get_typical_stop_list_by_direction(patterns, global)

        Enum.map([0, 1], fn direction_id ->
          new(direction_id, route, stop.id, stop_list_by_direction[direction_id])
        end)
      else
        Enum.map([0, 1], fn direction_id -> new(direction_id, route) end)
      end
    end

    def get_directions_for_line(global, stop, patterns) do
      directions_by_route =
        patterns
        |> Enum.group_by(& &1.route_id)
        |> Map.new(fn {route_id, patterns} ->
          route = global.routes[route_id] || []
          {route_id, get_directions(global, stop, route, patterns)}
        end)

      [0, 1]
      |> Enum.map(fn direction_id ->
        directions_by_destination =
          directions_by_route
          |> Enum.map(fn {_route_id, directions} -> Enum.at(directions, direction_id) end)
          |> Map.new(&{&1.destination, &1})

        cond do
          # When only one direction is in the set, it means that all the routes in the line share the same destination
          # at this stop, so we can safely display it.
          map_size(directions_by_destination) == 1 ->
            hd(Map.values(directions_by_destination))

          directions_by_destination == %{} ->
            # If this is true, the direction isn't served and shouldn't be displayed,
            # or something is wrong with the provided data.
            %__MODULE__{name: "", destination: "", id: direction_id}

          # Handle the unique mid-route terminal case at Government Center
          special_case = gov_center_special_case(directions_by_destination) ->
            special_case

          true ->
            # When multiple destinations are served in one direction, we don't want to display any destination label,
            # so it's set to null.
            representative_direction = hd(Map.values(directions_by_destination))
            %__MODULE__{name: representative_direction.name, destination: nil, id: direction_id}
        end
      end)
    end

    # This is hacky, but seemed like the best way to handle this case, where the Green Line has multiple routes which
    # terminate mid-line at Gov Center, but since those routes are served at the stop, it has non-null Direction objects
    # with Gov Center destinations. This checks if we have this specific case, and returns the North direction if we do.
    defp gov_center_special_case(directions_by_destination) do
      if Enum.sort(Map.keys(directions_by_destination)) ==
           Enum.sort(["Government Center", @north_station_destination]) do
        directions_by_destination[@north_station_destination]
      end
    end

    defp get_stop_list_for_pattern(pattern, global) do
      Enum.map(
        global.trips[pattern.representative_trip_id].stop_ids,
        &Stop.parent_id(global.stops[&1])
      )
    end

    defp get_typical_stop_list_by_direction(patterns, global) do
      patterns
      |> Enum.group_by(& &1.direction_id)
      |> Map.new(fn {direction_id, direction_patterns} ->
        stop_list =
          get_stop_list_for_pattern(
            Enum.find(direction_patterns, &(&1.typicality == :typical)),
            global
          )

        {direction_id, stop_list}
      end)
    end
  end

  defprotocol PolymorphicJson do
    @impl true
    defmacro __deriving__(module, _options) do
      type = module |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()

      quote do
        defimpl Jason.Encoder, for: unquote(module) do
          def encode(value, opts) do
            value |> Map.from_struct() |> Map.put(:type, unquote(type)) |> Jason.Encode.map(opts)
          end
        end

        defimpl JSON.Encoder, for: unquote(module) do
          def encode(value, encoder) do
            value |> Map.from_struct() |> Map.put(:type, unquote(type)) |> encoder.(encoder)
          end
        end
      end
    end

    def ok(this)
  end

  defmodule Location do
    defmodule DirectionToStop do
      @type t :: %__MODULE__{direction: Direction.t(), end_stop_name: String.t()}
      @derive PolymorphicJson
      defstruct [:direction, :end_stop_name]
    end

    defmodule SingleStop do
      @type t :: %__MODULE__{stop_name: String.t()}
      @derive PolymorphicJson
      defstruct [:stop_name]
    end

    defmodule StopToDirection do
      @type t :: %__MODULE__{start_stop_name: String.t(), direction: Direction.t()}
      @derive PolymorphicJson
      defstruct [:start_stop_name, :direction]
    end

    defmodule SuccessiveStops do
      @type t :: %__MODULE__{start_stop_name: String.t(), end_stop_name: String.t()}
      @derive PolymorphicJson
      defstruct [:start_stop_name, :end_stop_name]
    end

    @type t :: DirectionToStop.t() | SingleStop.t() | StopToDirection.t() | SuccessiveStops.t()
  end

  defmodule Timeframe do
    defmodule EndOfService do
      @type t :: %__MODULE__{}
      @derive PolymorphicJson
      defstruct []
    end

    defmodule Tomorrow do
      @type t :: %__MODULE__{}
      @derive PolymorphicJson
      defstruct []
    end

    defmodule LaterDate do
      @type t :: %__MODULE__{time: DateTime.t()}
      @derive PolymorphicJson
      defstruct [:time]
    end

    defmodule ThisWeek do
      @type t :: %__MODULE__{time: DateTime.t()}
      @derive PolymorphicJson
      defstruct [:time]
    end

    defmodule Time do
      @type t :: %__MODULE__{time: DateTime.t()}
      @derive PolymorphicJson
      defstruct [:time]
    end

    defmodule StartingTomorrow do
      @type t :: %__MODULE__{}
      @derive PolymorphicJson
      defstruct []
    end

    defmodule StartingLaterToday do
      @type t :: %__MODULE__{time: DateTime.t()}
      @derive PolymorphicJson
      defstruct [:time]
    end

    defmodule TimeRange do
      @type t :: %__MODULE__{start_time: start_time(), end_time: end_time()}
      @derive PolymorphicJson
      defstruct [:start_time, :end_time]

      defmodule StartOfService do
        @type t :: %__MODULE__{}
        @derive PolymorphicJson
        defstruct []
      end

      defmodule EndOfService do
        @type t :: %__MODULE__{}
        @derive PolymorphicJson
        defstruct []
      end

      defmodule Time do
        @type t :: %__MODULE__{time: DateTime.t()}
        @derive PolymorphicJson
        defstruct [:time]
      end

      @type start_time :: StartOfService.t() | Time.t()
      @type end_time :: EndOfService.t() | Time.t()
    end

    @type t ::
            EndOfService.t()
            | Tomorrow.t()
            | LaterDate.t()
            | ThisWeek.t()
            | Time.t()
            | StartingTomorrow.t()
            | StartingLaterToday.t()
  end

  defmodule Recurrence do
    @type end_day :: Timeframe.Tomorrow.t() | Timeframe.LaterDate.t() | Timeframe.ThisWeek.t()

    defmodule Daily do
      @type t :: %__MODULE__{ending: Recurrence.end_day()}
      @derive PolymorphicJson
      defstruct [:ending]
    end

    defmodule SomeDays do
      @type t :: %__MODULE__{ending: Recurrence.end_day()}
      @derive PolymorphicJson
      defstruct [:ending]
    end

    @type t :: Daily.t() | SomeDays.t()
  end

  @type t :: %__MODULE__{
          effect: Alert.effect(),
          location: Location.t() | nil,
          timeframe: Timeframe.t() | nil,
          recurrence: Recurrence.t() | nil
        }
  @derive JSON.Encoder
  @derive Jason.Encoder
  defstruct [:effect, :location, :timeframe, :recurrence]

  @spec summarizing(
          Alert.t(),
          Stop.id(),
          0 | 1,
          [RoutePattern.t()],
          DateTime.t(),
          GlobalDataCache.data()
        ) :: t()
  def summarizing(alert, stop_id, direction_id, patterns, at_time, global) do
    recurrence = alert_recurrence(alert, at_time)

    %__MODULE__{
      effect: alert.effect,
      location: alert_location(alert, stop_id, direction_id, patterns, global),
      timeframe: alert_timeframe(alert, at_time, not is_nil(recurrence)),
      recurrence: recurrence
    }
  end

  @spec alert_location(Alert.t(), Stop.id(), 0 | 1, [RoutePattern.t()], GlobalDataCache.data()) ::
          Location.t() | nil
  defp alert_location(alert, stop_id, direction_id, patterns, global) do
    routes =
      patterns
      |> Enum.uniq_by(& &1.route_id)
      |> Enum.map(&global.routes[&1.route_id])
      |> Enum.reject(&is_nil/1)

    affected_stops = get_alert_affected_stops(global, alert, routes)

    cond do
      length(affected_stops) == 1 ->
        %Location.SingleStop{stop_name: hd(affected_stops).name}

      # Never show multiple stops for bus
      Enum.any?(routes, &(&1.type == :bus and not String.starts_with?(&1.id, "Shuttle"))) ->
        nil

      true ->
        multi_stop_location(alert, stop_id, direction_id, patterns, routes, global)
    end
  end

  @spec alert_timeframe(Alert.t(), DateTime.t(), boolean()) :: Timeframe.t() | nil
  defp alert_timeframe(alert, at_time, has_recurrence?)

  defp alert_timeframe(%Alert{duration_certainty: :estimated}, _, _), do: nil

  defp alert_timeframe(alert, at_time, has_recurrence?) do
    service_date = Util.datetime_to_gtfs(at_time)

    case Alert.current_period(alert, at_time) do
      %Alert.ActivePeriod{end: end_time} = current_period when not is_nil(end_time) ->
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

      _ ->
        nil
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
    end_date = Util.datetime_to_gtfs(end_time, rounding: :backwards)

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
    start_service_date = Util.datetime_to_gtfs(start_time)

    if start_service_date == service_date do
      %Timeframe.StartingLaterToday{time: start_time}
    else
      %Timeframe.StartingTomorrow{}
    end
  end

  @spec alert_recurrence(Alert.t(), DateTime.t()) :: Recurrence.t() | nil
  defp alert_recurrence(alert, at_time) do
    with %Alert.RecurrenceInfo{end: last_period_end} = range <- Alert.recurrence_range(alert),
         service_date = Util.datetime_to_gtfs(at_time),
         last_service_date when last_service_date != service_date <-
           Util.datetime_to_gtfs(last_period_end, rounding: :backwards) do
      ending =
        cond do
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

  defp multi_stop_location(alert, stop_id, direction_id, patterns, routes, global) do
    # Map each pattern to its list of stops affected by this alert
    affected_pattern_stops =
      map_patterns_to_affected_stops(alert, stop_id, direction_id, patterns, routes, global)

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
          end_stop_name: List.last(ordered_stops).name
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
          direction: Enum.at(directions, direction_id)
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
          end_stop_name: stop.name
        }

      true ->
        nil
    end
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
        trip = global.trips[pattern.representative_trip_id]
        {pattern, trip.stop_ids}
      end)
      |> Kernel.++(
        # Special casing to properly show when alerts affect multiple GL branches
        if Enum.any?(routes, &(&1.line_id == "line-Green")) do
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

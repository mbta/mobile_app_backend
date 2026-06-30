defmodule MobileAppBackend.Alerts.AlertSummary.Direction do
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip

  @type t :: %__MODULE__{name: String.t() | nil, destination: String.t() | nil, id: 0 | 1}
  @derive JSON.Encoder
  @derive Jason.Encoder

  defstruct [:name, :destination, :id]

  @spec new(0 | 1, any()) :: MobileAppBackend.Alerts.AlertSummary.Direction.t()
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

  @spec get_directions_for_line(GlobalDataCache.data(), Stop.t(), [RoutePattern.t()]) :: [t()]
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
  @spec gov_center_special_case(%{(String.t() | nil) => t()}) :: t() | nil
  defp gov_center_special_case(directions_by_destination) do
    if Enum.sort(Map.keys(directions_by_destination)) ==
         Enum.sort(["Government Center", @north_station_destination]) do
      directions_by_destination[@north_station_destination]
    end
  end

  @spec get_stop_list_for_pattern(RoutePattern.t(), GlobalDataCache.data()) :: [Stop.id()]
  defp get_stop_list_for_pattern(pattern, global) do
    Enum.map(
      case global.trips[pattern.representative_trip_id] do
        %Trip{} = trip -> trip.stop_ids
        _ -> []
      end,
      &Stop.parent_id(global.stops[&1])
    )
  end

  @spec get_typical_stop_list_by_direction([RoutePattern.t()], GlobalDataCache.data()) :: %{
          integer() => [Stop.id()] | nil
        }
  defp get_typical_stop_list_by_direction(patterns, global) do
    patterns
    |> Enum.group_by(& &1.direction_id)
    |> Map.new(fn {direction_id, direction_patterns} ->
      maybe_typical_pattern = Enum.find(direction_patterns, &(&1.typicality == :typical))

      stop_list =
        if is_nil(maybe_typical_pattern) do
          nil
        else
          get_stop_list_for_pattern(
            maybe_typical_pattern,
            global
          )
        end

      {direction_id, stop_list}
    end)
  end
end

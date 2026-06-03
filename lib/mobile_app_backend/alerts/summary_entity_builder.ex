defmodule MobileAppBackend.Alerts.SummaryEntityBuilder do
  alias MBTAV3API.Alert
  alias MBTAV3API.Repository
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Schedule
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip
  alias MobileAppBackend.Alerts.AlertSummary
  alias MobileAppBackend.Alerts.FormattedAlert
  alias MobileAppBackend.Alerts.SummaryEntity
  alias MobileAppBackend.GlobalDataCache

  defmodule Combination do
    @type t :: %__MODULE__{
            route: String.t() | nil,
            stop: String.t() | nil,
            trip: String.t() | nil,
            direction: 0 | 1 | nil
          }
    defstruct [:route, :stop, :trip, :direction]
  end

  @doc """
  Given a list of alerts and global data, produces a list of summary entites keyed by alert id
  """
  @spec build_all([Alert.t()], DateTime.t(), String.t(), GlobalDataCache.data()) :: %{
          String.t() => [SummaryEntity.t()]
        }
  def build_all(alerts, at_time, locale, global) do
    Map.new(
      Enum.map(alerts, fn alert -> {alert.id, build_for_alert(alert, at_time, locale, global)} end)
    )
  end

  @spec build_all([Alert.t()], String.t()) :: %{String.t() => [SummaryEntity.t()]}
  def build_all(alerts, locale) do
    at_time = DateTime.now!("America/New_York")
    global = GlobalDataCache.get_data()

    build_all(alerts, at_time, locale, global)
  end

  @spec build_for_alert(Alert.t(), DateTime.t(), String.t(), GlobalDataCache.data()) :: [
          SummaryEntity.t()
        ]
  defp build_for_alert(alert, at_time, locale, global) do
    # Fetch schedules once for the whole alert for any trips included in the informed entities
    {schedules, trips} = fetch_schedules_for_alert(alert)

    # The global stops don't include all child stops, so we need to fetch them separately
    stops = fetch_all_stops()

    combinations = relevant_combinations(alert, stops, global)

    Enum.flat_map(
      combinations,
      &combination_to_summaries(&1, alert, at_time, locale, schedules, trips, stops, global)
    )
    |> dedup_summaries()
  end

  defp combination_to_summaries(
         %Combination{
           route: route_id,
           stop: stop_id,
           trip: trip_id,
           direction: direction_id
         },
         alert,
         at_time,
         locale,
         schedules,
         trips,
         stops,
         global
       ) do
    RoutePattern.get_relevant_patterns(route_id, stop_id, direction_id, global)
    |> Enum.group_by(&{&1.route_id, &1.direction_id})
    |> Enum.map(fn {{resolved_route_id, resolved_direction_id}, patterns} ->
      resolved_stop_id = resolve_stop_id(stop_id, trip_id, patterns, trips, stops, global)

      resolved_schedules =
        filter_schedules(
          schedules,
          trips,
          resolved_route_id,
          resolved_stop_id,
          resolved_direction_id,
          stops,
          global
        )

      summary =
        AlertSummary.summarizing(
          alert,
          resolved_stop_id,
          resolved_direction_id,
          patterns,
          at_time,
          resolved_schedules,
          global
        )

      formatted =
        FormattedAlert.summary(
          %FormattedAlert{alert: alert, alert_summary: summary},
          locale
        )

      %SummaryEntity{
        alert_id: alert.id,
        route_id: resolved_route_id,
        stop_id: stop_id,
        trip_id: trip_id,
        direction_id: resolved_direction_id,
        summary: formatted
      }
    end)
  end

  # Get the route, stop, trip, and direction combinations relevant to the alert based on its informed_entity list
  @spec relevant_combinations(Alert.t(), %{String.t() => Stop.t()}, GlobalDataCache.data()) :: [
          Combination.t()
        ]
  defp relevant_combinations(alert, stops, global) do
    combinations =
      alert.informed_entity
      |> Enum.flat_map(&combination_from_entity(&1, global))
      |> Enum.map(fn %Combination{route: route, stop: stop, trip: trip, direction: direction} ->
        %Combination{
          route: route,
          stop: stop_parent_id(stop, stops),
          trip: trip,
          direction: direction
        }
      end)
      |> Enum.uniq()

    # Filter out any combinations that are already covered by another wildcard in the list
    # We don't need to check nil direction wildcards because any nils in the input will have been
    # expanded to both directions
    Enum.reject(combinations, fn combination ->
      redundant_combination?(combination, :route, combinations) and
        redundant_combination?(combination, :stop, combinations) and
        redundant_combination?(combination, :trip, combinations)
    end)
  end

  @spec combination_from_entity(Alert.InformedEntity.t(), GlobalDataCache.data()) :: [
          {String.t() | nil, String.t() | nil, String.t() | nil, 0 | 1 | nil}
        ]
  defp combination_from_entity(entity, global) do
    case entity do
      # Expand route type entities into a combination for each route of that type,
      # since each route will have a different summary
      %Alert.InformedEntity{route_type: route_type, route: nil, stop: nil, direction_id: nil}
      when not is_nil(route_type) ->
        global.routes
        |> Enum.filter(fn route -> route.type == Route.parse_type!(route_type) end)
        |> Enum.map(fn {route_id, _} -> %Combination{route: route_id} end)

      %Alert.InformedEntity{
        route: route_id,
        stop: stop_id,
        trip: trip_id,
        direction_id: direction_id
      }
      when not is_nil(trip_id) ->
        [%Combination{route: route_id, stop: stop_id, trip: trip_id, direction: direction_id}]

      %Alert.InformedEntity{route: route_id, stop: stop_id, direction_id: nil}
      when not is_nil(stop_id) or not is_nil(route_id) ->
        [
          %Combination{route: route_id, stop: stop_id, direction: 0},
          %Combination{route: route_id, stop: stop_id, direction: 1}
        ]

      %Alert.InformedEntity{route: route_id, stop: stop_id, direction_id: direction_id}
      when not is_nil(stop_id) or not is_nil(route_id) ->
        [%Combination{route: route_id, stop: stop_id, direction: direction_id}]

      _ ->
        []
    end
  end

  # A combination is redundant if there exists another combination in the list that matches it
  # on all non-nil fields except for the field at the given index, where the other combination has nil.
  @spec redundant_combination?(
          Combination.t(),
          :route | :stop | :trip,
          [Combination.t()]
        ) :: boolean()
  defp redundant_combination?(combination, key, combinations) do
    match_key? = fn combination, other, check_key ->
      if check_key == key,
        do: is_nil(Map.get(other, check_key)),
        else: Map.get(other, check_key) == Map.get(combination, check_key)
    end

    not is_nil(Map.get(combination, key)) and
      Enum.any?(combinations, fn other ->
        Enum.all?(Map.keys(combination), &match_key?.(combination, other, &1))
      end)
  end

  defp fetch_all_stops do
    {:ok, %{data: stops}} =
      Repository.stops(include: [:child_stops])

    Map.new(stops, &{&1.id, &1})
  end

  @spec resolve_stop_id(
          String.t() | nil,
          String.t() | nil,
          [RoutePattern.t()],
          %{String.t() => Trip.t()},
          %{String.t() => Stop.t()},
          GlobalDataCache.data()
        ) :: String.t() | nil
  defp resolve_stop_id(stop_id, trip_id, patterns, trips, stops, global) do
    # If a stop ID is provided in the informed entities, we can return it directly,
    # but if not, we need to determine a relevant stop from the pattern or trip
    stop_id ||
      stop_parent_id(
        case trip_id do
          nil ->
            # We need to provide a specific stop ID to AlertSummary.summarizing, but if the informed entity
            # only specifies a route ID without a stop or trip, the only way for us to get a relevant stop ID
            # is to pull one from a pattern's representative trip, since the summary shouldn't be different across stops
            RoutePattern.canonical_or_most_typical(patterns)
            |> List.first()
            |> case do
              %RoutePattern{representative_trip_id: representative_trip_id} ->
                global.trips[representative_trip_id].stop_ids |> List.first()

              _ ->
                nil
            end

          _ ->
            # If a trip ID is provided, we can pull a stop ID from the trip's stop list
            trips[trip_id].stop_ids |> List.first()
        end,
        stops
      )
  end

  def stop_parent_id(nil, _stops), do: nil

  def stop_parent_id(stop_id, stops) do
    case Stop.parent_if_exists(
           stops[stop_id],
           stops
         ) do
      %Stop{id: id} -> id
      _ -> nil
    end
  end

  # Fetch schedules for all trip IDs referenced in the alert's informed_entity list
  @spec fetch_schedules_for_alert(Alert.t()) ::
          {[Schedule.t()] | nil, %{String.t() => Trip.t()} | nil}
  defp fetch_schedules_for_alert(alert) do
    trip_ids =
      alert.informed_entity
      |> Enum.map(& &1.trip)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    case trip_ids do
      [] ->
        {nil, nil}

      trip_ids ->
        case Repository.schedules(
               filter: [trip: trip_ids],
               include: [trip: :stops],
               sort: {:stop_sequence, :asc}
             ) do
          {:ok, %{data: schedules, included: %{trips: trips}}} -> {schedules, trips}
          _ -> {nil, nil}
        end
    end
  end

  # Get the schedules relevant to a particular combination of route, stop, direction
  # by filtering the full list of schedules for the alert
  @spec filter_schedules(
          [Schedule.t()] | nil,
          %{String.t() => Trip.t()} | nil,
          String.t(),
          String.t(),
          0 | 1,
          %{String.t() => Stop.t()},
          GlobalDataCache.data()
        ) :: [Schedule.t()] | nil
  defp filter_schedules(schedules, trips, _route_id, _stop_id, _direction_id, _stops, _global)
       when is_nil(schedules) or is_nil(trips),
       do: nil

  defp filter_schedules(schedules, trips, route_id, stop_id, direction_id, stops, global) do
    Enum.filter(schedules, fn schedule ->
      route_matches? =
        schedule.route_id == route_id or
          global.routes[schedule.route_id].line_id == route_id

      stop_matches? =
        schedule.stop_id == stop_id or stop_parent_id(schedule.stop_id, stops) == stop_id

      direction_matches? =
        case trips[schedule.trip_id] do
          %Trip{direction_id: ^direction_id} -> true
          _ -> direction_id == nil
        end

      route_matches? and stop_matches? and direction_matches?
    end)
  end

  # Collapse entities where both directions produce identical summaries
  @spec dedup_summaries([SummaryEntity.t()]) :: [SummaryEntity.t()]
  defp dedup_summaries(entities) do
    entities
    |> Enum.group_by(&{&1.alert_id, &1.route_id, &1.trip_id, &1.stop_id})
    |> Enum.flat_map(fn {_key, grouped} ->
      case grouped do
        [a, b] when a.summary == b.summary ->
          [%{a | direction_id: nil}]

        _ ->
          grouped
      end
    end)
  end
end

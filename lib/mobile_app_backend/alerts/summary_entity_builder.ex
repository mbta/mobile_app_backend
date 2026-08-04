defmodule MobileAppBackend.Alerts.SummaryEntityBuilder do
  require Logger
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
    @moduledoc "specific parameters for an individual summary"
    @type t :: %__MODULE__{
            route: Route.id(),
            stop: Stop.id() | nil,
            direction: 0 | 1,
            trip: Trip.id() | nil,
            patterns: [RoutePattern.t()]
          }
    @enforce_keys [:route, :stop, :direction, :trip, :patterns]
    defstruct [:route, :stop, :direction, :trip, :patterns]
  end

  @doc """
  Given a list of alerts and global data, produces a list of summary entities keyed by alert id.

  Includes summaries for stops that are not directly affected, so that the frontend can correctly
  display downstream alerts where needed.
  Note that summary entities may match routes/stops/directions/trips where the alert itself
  should not be displayed: the frontend will still decide whether or not to actually show the
  alert, and the summary entity only determines which summary text will be displayed.
  """
  @spec build_all(
          [Alert.t()],
          DateTime.t(),
          String.t(),
          GlobalDataCache.data(),
          AlertSummary.context()
        ) :: %{String.t() => [SummaryEntity.t()]}
  def build_all(alerts, at_time, locale, global, context) do
    Map.new(
      Enum.map(alerts, fn alert ->
        {alert.id, build_for_alert(alert, at_time, locale, global, context)}
      end)
    )
  end

  @spec build_all([Alert.t()], String.t(), AlertSummary.context()) ::
          %{String.t() => [SummaryEntity.t()]}
  def build_all(alerts, locale, context) do
    at_time = DateTime.now!("America/New_York")
    global = GlobalDataCache.get_data()

    build_all(alerts, at_time, locale, global, context)
  end

  @spec build_for_alert(
          Alert.t(),
          DateTime.t(),
          String.t(),
          GlobalDataCache.data(),
          AlertSummary.context()
        ) :: [SummaryEntity.t()]
  defp build_for_alert(alert, at_time, locale, global, context) do
    # Fetch schedules once for the whole alert for any trips included in the informed entities
    {schedules, trips} = fetch_schedules_for_alert(alert)

    # The global stops don't include all child stops, so we need to fetch them separately
    stops = fetch_all_stops()

    combinations = relevant_combinations(alert, {stops, trips, global})

    Enum.map(
      combinations,
      &combination_to_summary(
        &1,
        alert,
        at_time,
        locale,
        {schedules, trips, stops},
        global,
        context
      )
    )
    |> dedup_summaries()
  end

  @spec combination_to_summary(
          Combination.t(),
          Alert.t(),
          DateTime.t(),
          String.t(),
          {[Schedule.t()] | nil, %{Trip.id() => Trip.t()} | nil, %{Stop.id() => Stop.t()}},
          GlobalDataCache.data(),
          AlertSummary.context()
        ) :: SummaryEntity.t()
  defp combination_to_summary(
         %Combination{
           route: route_id,
           stop: stop_id,
           direction: direction_id,
           trip: trip_id,
           patterns: patterns
         },
         alert,
         at_time,
         locale,
         {schedules, trips, stops},
         global,
         context
       ) do
    resolved_stop_id = resolve_stop_id(stop_id, trip_id, patterns, trips, stops, global)

    resolved_schedules =
      filter_schedules(
        schedules,
        trips,
        route_id,
        resolved_stop_id,
        direction_id,
        stops,
        global
      )

    summary =
      AlertSummary.summarizing(
        alert,
        resolved_stop_id,
        direction_id,
        patterns,
        at_time,
        resolved_schedules,
        global,
        context
      )

    formatted =
      FormattedAlert.summary(
        %FormattedAlert{alert: alert, alert_summary: summary},
        locale
      )

    %SummaryEntity{
      route_id: route_id,
      stop_id: stop_id,
      trip_id: trip_id,
      direction_id: direction_id,
      summary: formatted
    }
  end

  # Get the route, stop, trip, and direction combinations relevant to the alert based on its informed_entity list
  @spec relevant_combinations(
          Alert.t(),
          {%{Stop.id() => Stop.t()}, %{Trip.id() => Trip.t()}, GlobalDataCache.data()}
        ) ::
          [Combination.t()]
  def relevant_combinations(alert, {all_child_stops, trips, global}) do
    alert.informed_entity
    |> Enum.flat_map(&expand_entity(&1, {all_child_stops, trips, global}))
    |> Enum.uniq()
    |> Enum.flat_map(&combinations_from_entity(&1, trips, global))
    |> Enum.uniq()
  end

  @spec expand_entity(
          Alert.InformedEntity.t(),
          {all_child_stops :: %{Stop.id() => Stop.t()}, trips :: %{Trip.id() => Trip.t()},
           global :: GlobalDataCache.data()}
        ) ::
          [Alert.InformedEntity.t()]
  defp expand_entity(ie, extra_context)

  defp expand_entity(
         %Alert.InformedEntity{route: nil, route_type: route_type} = ie,
         {all_child_stops, trips, global}
       )
       when not is_nil(route_type) do
    global.routes
    |> Enum.filter(fn {_id, route} -> route.type == route_type end)
    |> Enum.flat_map(fn {route_id, _} ->
      expand_entity(%Alert.InformedEntity{ie | route: route_id}, {all_child_stops, trips, global})
    end)
  end

  defp expand_entity(
         %Alert.InformedEntity{route: nil, stop: stop} = ie,
         {all_child_stops, trips, global}
       )
       when not is_nil(stop) do
    # check all the patterns at this stop to find their routes and directions
    parent_stop = global.stops[stop_parent_id(stop, all_child_stops)]
    all_stop_ids = [parent_stop | parent_stop.child_stop_ids || []]

    all_stop_ids
    |> Enum.flat_map(&(global.pattern_ids_by_stop[&1] || []))
    |> Enum.map(fn pattern_id ->
      pattern = global.route_patterns[pattern_id]

      %Alert.InformedEntity{
        ie
        | direction_id: pattern.direction_id,
          route: pattern.route_id,
          stop: nil
      }
    end)
    |> Enum.uniq()
    |> Enum.flat_map(&expand_entity(&1, {all_child_stops, trips, global}))
  end

  defp expand_entity(
         %Alert.InformedEntity{direction_id: nil} = ie,
         {all_child_stops, trips, global}
       ) do
    directions =
      if is_nil(ie.trip) do
        [0, 1]
      else
        [trips[ie.trip].direction_id]
      end

    Enum.flat_map(
      directions,
      &expand_entity(
        %Alert.InformedEntity{ie | direction_id: &1},
        {all_child_stops, trips, global}
      )
    )
  end

  defp expand_entity(
         %Alert.InformedEntity{direction_id: direction_id, route: route} = ie,
         _extra_context
       )
       when not is_nil(direction_id) and not is_nil(route) do
    [ie]
  end

  defp expand_entity(ie, _extra_context) do
    Logger.warning("expand_entity/2 unknown entity #{inspect(ie)}")
    Sentry.capture_message("expand_entity/2 unknown entity #{inspect(ie)}")
    []
  end

  @spec combinations_from_entity(
          Alert.InformedEntity.t(),
          %{Trip.id() => Trip.t()},
          GlobalDataCache.data()
        ) ::
          [Combination.t()]
  defp combinations_from_entity(
         %Alert.InformedEntity{direction_id: direction_id, route: route_id, trip: trip_id},
         trips,
         global
       ) do
    patterns = RoutePattern.get_relevant_patterns(route_id, nil, direction_id, global)

    cond do
      not is_nil(trip_id) ->
        # for trip-specific alerts, we usually need the stop id for trip identity,
        # and we only want the stops the trip will actually visit
        trip = trips[trip_id]

        if is_nil(trip) do
          Logger.error("unknown trip #{trip_id} for route #{route_id} direction #{direction_id}")
          []
        else
          pattern = Enum.find(patterns, &(&1.id == trip.route_pattern_id))
          stop_ids = trip.stop_ids

          Enum.map(stop_ids, fn stop_id ->
            stop_id = Stop.parent_id_if_exists(stop_id, global.stops)

            %Combination{
              route: route_id,
              stop: stop_id,
              direction: direction_id,
              trip: trip_id,
              patterns: List.wrap(pattern)
            }
          end)
        end

      String.starts_with?(route_id, "Green-") or length(patterns) > 1 ->
        # for branching routes or the Green Line, the summary may differ by stop id
        patterns
        |> Enum.flat_map(fn pattern ->
          pattern_stop_ids = global.trips[pattern.representative_trip_id].stop_ids
          Enum.map(pattern_stop_ids, &{Stop.parent_id_if_exists(&1, global.stops), pattern})
        end)
        |> Enum.group_by(fn {stop_id, _pattern} -> stop_id end, fn {_stop_id, pattern} ->
          pattern
        end)
        |> Enum.map(fn {stop_id, patterns} ->
          %Combination{
            route: route_id,
            stop: stop_id,
            direction: direction_id,
            trip: nil,
            patterns: patterns
          }
        end)

      true ->
        # in all other cases, the stop id doesn’t matter
        [
          %Combination{
            route: route_id,
            stop: nil,
            direction: direction_id,
            trip: nil,
            patterns: patterns
          }
        ]
    end
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
            Map.get(trips, trip_id, %{stop_ids: []}).stop_ids |> List.first()
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
          {:ok, %{data: schedules, included: %{trips: trips}}} ->
            {schedules, trips}

          response ->
            Logger.error(
              "failed to fetch schedules for trip_ids #{inspect(trip_ids)} response=#{inspect(response)}"
            )

            {nil, nil}
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

  # Discard specifiers that aren’t necessary to distinguish between summaries
  @spec dedup_summaries([SummaryEntity.t()]) :: [SummaryEntity.t()]
  def dedup_summaries(entities) do
    # sorted from most desirable to collapse into wildcards to least desirable
    all_keys = [:stop_id, :trip_id, :direction_id, :route_id]

    for split_key <- all_keys, reduce: entities do
      entities ->
        other_keys = all_keys -- [split_key]
        # we can drop this key if the other keys are sufficient to uniquely determine the summary
        summaries_by_other_keys =
          Enum.group_by(
            entities,
            fn entity -> Map.take(entity, other_keys) end,
            fn entity -> entity.summary end
          )

        can_drop_split_key? =
          summaries_by_other_keys |> Map.values() |> Enum.all?(&(length(Enum.uniq(&1)) == 1))

        if can_drop_split_key? do
          entities |> Enum.map(&Map.put(&1, split_key, nil)) |> Enum.uniq()
        else
          entities
        end
    end
  end
end

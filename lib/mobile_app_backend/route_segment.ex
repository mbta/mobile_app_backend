defmodule MobileAppBackend.RouteSegment do
  @doc """
  A route segment is a conceptual chunk of a route between a set of stops.
  It can be used to break overlapping route patterns into non-overlapping segments.
  For example, the two southbound Red Line route patterns have representative trips
  with the following stops:
  * Alewife - Ashmont
  * Alewife - Braintree
  with the set of stops Alewife - JFK/UMass represented in both patterns.

  These two route patterns could be represented as the following non-overlapping RouteSegments:
  * Alewife - Ashmont
  * JFK/UMass - Braintree
  Note the 'boundary stop' of JFK/UMass where these segments intersect is included in each segment.
  """
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip

  @type route_pattern_key :: %{route_id: Route.id(), route_pattern_id: RoutePattern.id()}

  @type t :: %__MODULE__{
          id: String.t(),
          source_route_pattern_id: RoutePattern.id(),
          source_route_id: Route.id(),
          stop_ids: [Stop.id()],
          other_patterns_by_stop_id: %{Stop.id() => [route_pattern_key()]}
        }

  @typep route_pattern_with_stops :: %{
           id: RoutePattern.id(),
           route_id: Route.id(),
           stops: [Stop.t()]
         }

  @derive Jason.Encoder
  defstruct [
    :id,
    :source_route_pattern_id,
    :source_route_id,
    :stop_ids,
    other_patterns_by_stop_id: %{}
  ]

  @spec segment_per_pattern(
          [RoutePattern.t()],
          %{Stop.id() => Stop.t()},
          %{Trip.id() => Trip.t()},
          %{Route.id() => String.t()}
        ) :: [t()]
  @doc """
  Returns a single RouteSegment per RoutePattern containing all stops served by that pattern.
  Uses a route pattern's route_id by default to group related route patterns, or an override
  if present in the `route_id_to_grouping_id` map. This will use parent stops wherever possible
  to detect which other route patterns serve that stop.
  """
  def segment_per_pattern(
        route_patterns,
        stops_by_id,
        trips_by_id,
        route_id_to_grouping_id \\ %{}
      ) do
    route_patterns
    |> route_patterns_with_parent_stops(stops_by_id, trips_by_id)
    |> Enum.group_by(&Map.get(route_id_to_grouping_id, &1.route_id, &1.route_id))
    |> Enum.flat_map(fn {_route_id, route_patterns} ->
      segment_per_pattern(route_patterns)
    end)
    |> Enum.sort_by(& &1.source_route_pattern_id)
  end

  defp segment_per_pattern(rps_with_stops) do
    stop_id_to_rps =
      rps_with_stops
      |> Enum.flat_map(
        &Enum.map(&1.stops, fn stop ->
          {stop.id, %{route_id: &1.route_id, route_pattern_id: &1.id}}
        end)
      )
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    Enum.map(
      rps_with_stops,
      &%__MODULE__{
        id: "#{List.first(&1.stops).id}-#{List.last(&1.stops).id}",
        source_route_pattern_id: &1.id,
        source_route_id: &1.route_id,
        stop_ids: Enum.map(&1.stops, fn stop -> stop.id end),
        other_patterns_by_stop_id: other_patterns_by_stop_id(&1.id, &1.stops, stop_id_to_rps)
      }
    )
  end

  @spec non_overlapping_segments(
          [RoutePattern.t()],
          %{Stop.id() => Stop.t()},
          %{Trip.id() => Trip.t()},
          %{Route.id() => String.t()}
        ) :: [t()]
  @doc """
  Get a list of non-overlapping RouteSegments within a route for the list of route patterns.
  Uses a route pattern's route_id by default to group related route patterns, or an override if present
  in the `route_id_to_grouping_id` map.
  This will use parent stops wherever possible to detect when route patterns serve an overlapping set of stops.
  """
  def non_overlapping_segments(
        route_patterns,
        stops_by_id,
        trips_by_id,
        route_id_to_grouping_id \\ %{}
      ) do
    route_patterns
    |> route_patterns_with_parent_stops(stops_by_id, trips_by_id)
    |> Enum.group_by(&Map.get(route_id_to_grouping_id, &1.route_id, &1.route_id))
    |> Enum.flat_map(fn {_route_id, route_patterns} ->
      non_overlapping_segments(route_patterns)
    end)
    |> Enum.sort_by(& &1.source_route_pattern_id)
  end

  @spec non_overlapping_segments([route_pattern_with_stops()]) :: [t()]
  @doc """
  Return the list of non-overlapping RouteSegment's for the list of route patterns with associated stops.
  """
  def non_overlapping_segments(route_patterns_with_stops) do
    stop_id_to_route_patterns = stop_id_to_route_patterns(route_patterns_with_stops)

    build_non_overlapping_segments(
      route_patterns_with_stops,
      MapSet.new(),
      stop_id_to_route_patterns,
      []
    )
  end

  @spec stop_id_to_route_patterns([route_pattern_with_stops()]) :: %{
          Stop.id() => route_pattern_key()
        }
  defp stop_id_to_route_patterns(route_patterns_with_stops) do
    route_patterns_with_stops
    |> Enum.flat_map(fn rp_with_stops ->
      Enum.map(
        rp_with_stops.stops,
        &{&1.id, %{route_id: rp_with_stops.route_id, route_pattern_id: rp_with_stops.id}}
      )
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @spec build_non_overlapping_segments(
          [route_pattern_with_stops()],
          MapSet.t(Stop.id()),
          %{Stop.id() => [%{route_id: Route.id(), route_pattern_id: RoutePattern.id()}]},
          [t()]
        ) ::
          [t()]
  # Build the list of RouteSegments. For each route pattern, consider only the stops on that route pattern
  # Which have not been included on an earlier RouteSegment.
  defp build_non_overlapping_segments(
         [route_pattern | rest],
         seen_stop_ids,
         stop_id_to_route_patterns,
         acc_segments
       ) do
    all_stop_ids_for_rp = Enum.map(route_pattern.stops, & &1.id)

    unseen_stop_ids =
      all_stop_ids_for_rp
      |> MapSet.new()
      |> MapSet.difference(seen_stop_ids)

    new_segments =
      route_pattern
      |> unseen_stop_segments(unseen_stop_ids)
      |> Enum.map(fn stops ->
        stop_segment_to_route_segment(route_pattern, stops, stop_id_to_route_patterns)
      end)

    build_non_overlapping_segments(
      rest,
      MapSet.union(seen_stop_ids, unseen_stop_ids),
      stop_id_to_route_patterns,
      new_segments ++ acc_segments
    )
  end

  defp build_non_overlapping_segments(
         [],
         _seen_stop_ids,
         _stop_ids_to_route_patterns,
         acc_segments
       ) do
    Enum.reverse(acc_segments)
  end

  @spec stop_segment_to_route_segment(route_pattern_with_stops(), [Stop.t()], %{
          Stop.id() => route_pattern_key()
        }) :: t()
  defp stop_segment_to_route_segment(route_pattern, stop_segment, stop_id_to_route_patterns) do
    source_route_pattern_id = route_pattern.id
    source_route_id = route_pattern.route_id

    other_patterns_by_stop_id =
      other_patterns_by_stop_id(route_pattern.id, stop_segment, stop_id_to_route_patterns)

    %__MODULE__{
      id: "#{List.first(stop_segment).id}-#{List.last(stop_segment).id}",
      source_route_pattern_id: source_route_pattern_id,
      source_route_id: source_route_id,
      stop_ids: Enum.map(stop_segment, & &1.id),
      other_patterns_by_stop_id: other_patterns_by_stop_id
    }
  end

  @spec other_patterns_by_stop_id(RoutePattern.id(), [Stop.id()], %{
          Stop.id() => [route_pattern_key()]
        }) :: %{Stop.id() => [route_pattern_key()]}
  defp other_patterns_by_stop_id(route_pattern_id, stops, all_patterns_by_stop_id) do
    all_patterns_by_stop_id
    |> Map.take(Enum.map(stops, & &1.id))
    |> Enum.map(fn {stop_id, rp_keys} ->
      {stop_id,
       Enum.filter(
         rp_keys,
         &(&1.route_pattern_id != route_pattern_id &&
             &1.route_id != route_pattern_id)
       )}
    end)
    |> Enum.reject(fn {_stop_id, rp_keys} -> rp_keys == [] end)
    |> Map.new()
  end

  @spec unseen_stop_segments(route_pattern_with_stops(), MapSet.t(Stop.id())) :: [
          [Stop.t()]
        ]
  @doc """
  Return lists of consecutive stops that form line segments for the unseen set of stops.
  """
  def unseen_stop_segments(route_pattern_with_stops, unseen_stop_ids) do
    route_pattern_original_stops = route_pattern_with_stops.stops

    new_segments =
      route_pattern_original_stops
      |> segment_stops_including_boundary(fn stop ->
        !MapSet.member?(unseen_stop_ids, stop.id)
      end)
      |> Enum.reject(fn {is_overlapping_segment, _stops} ->
        is_overlapping_segment
      end)
      |> Enum.map(fn {_is_overlapping_segment, stops} -> stops end)

    new_segments
  end

  @spec segment_stops_including_boundary([Stop.t()], (Stop.t() -> any())) :: [
          {boolean(), [Stop.t()]}
        ]
  @doc """
  Split the list of stops into segments based on the evaluation of the `condition_eval_fn`.
  At a boundary where the `condition_eval_fn` switches from false to true or true to false,
  the stop that evaluated to true is included in both segments.

  For example:
  Stops [1, 2, 3, 4, 5, 6]. If condition_eval_fn is true when 3 <= stop <= 5, the resulting
  segments would be
  [{false, [1, 2, 3]}, {true, [3, 4, 5]}, {false, 5, 6}]
  """
  def segment_stops_including_boundary([stop | rest], condition_eval_fn) do
    segment_stops_including_boundary(
      rest,
      condition_eval_fn,
      {condition_eval_fn.(stop), [stop]},
      []
    )
  end

  def segment_stops_including_boundary([], _condition_eval_fn) do
    []
  end

  @spec segment_stops_including_boundary(
          [Stop.t()],
          (Stop.t() -> any()),
          {boolean(), [Stop.t()]},
          [{boolean(), [Stop.t()]}]
        ) :: [
          {boolean(), [Stop.t()]}
        ]
  defp segment_stops_including_boundary(
         [],
         _condition_eval_fn,
         {current_segment_eval, current_segment_stops},
         acc_segments
       ) do
    # Base case. segments accumulated in reverse, so reverse them
    # to get segments in the original order of stops
    all_segments = [{current_segment_eval, current_segment_stops} | acc_segments]

    all_segments
    |> Enum.map(fn {eval, stops} ->
      {eval, Enum.reverse(stops)}
    end)
    |> Enum.reverse()
  end

  defp segment_stops_including_boundary(
         [stop | rest],
         condition_eval_fn,
         {segment_eval, [previous_stop | _rest_of_segment] = current_segment_stops},
         acc_segments
       ) do
    current_stop_matches_condition = condition_eval_fn.(stop)

    if current_stop_matches_condition != segment_eval do
      # the current stop is a segment boundary.
      {next_segment, next_acc_segments} =
        if current_stop_matches_condition do
          # current stop is true, previous_stop is false.
          # add this stop to the current segment and move it to the accumulator.
          # Start a new segment with the current stop
          {{current_stop_matches_condition, [stop]},
           [{segment_eval, [stop | current_segment_stops]} | acc_segments]}
        else
          # current stop is false, previous_stop is true.
          # The previous_stop is the last stop in the segment - move the current
          # segment to the accumulator and start a new one, beginning with the previous stop.
          {{current_stop_matches_condition, [stop, previous_stop]},
           [{segment_eval, current_segment_stops} | acc_segments]}
        end

      segment_stops_including_boundary(
        rest,
        condition_eval_fn,
        next_segment,
        next_acc_segments
      )
    else
      # not at a segment boundary. Add the stop to the current segment & keep going
      segment_stops_including_boundary(
        rest,
        condition_eval_fn,
        {segment_eval, [stop | current_segment_stops]},
        acc_segments
      )
    end
  end

  @spec route_patterns_with_parent_stops([RoutePattern.t()], %{String.t() => Stop}, %{
          String.t() => Trip
        }) ::
          [route_pattern_with_stops()]
  @doc """
  Associate route patterns with the list of stops for their representative trips, using the parent
  stop when available.
  """
  def route_patterns_with_parent_stops(route_patterns, stops_by_id, trips_by_id) do
    route_patterns
    |> Enum.map(fn route_pattern ->
      representative_trip = Map.fetch!(trips_by_id, route_pattern.representative_trip_id)
      stops = parents_if_exist(representative_trip.stop_ids, stops_by_id)
      %{id: route_pattern.id, route_id: route_pattern.route_id, stops: stops}
    end)
  end

  @spec parents_if_exist([Stop.id()], %{Stop.id() => t()}) :: [t()]
  defp parents_if_exist(stop_ids, stops_by_id) do
    stop_ids
    |> Enum.map(&Map.get(stops_by_id, &1))
    |> Enum.reject(&is_nil(&1))
    |> Enum.map(&Stop.parent_if_exists(&1, stops_by_id))
  end
end

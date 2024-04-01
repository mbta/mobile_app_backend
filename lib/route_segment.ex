defmodule MobileAppBackend.RouteSegment do
  @doc """
  A route segment is a conceptual chunk of a route between a set of stops.
  It is a way to break overlapping route patterns into non-overlapping segments.
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
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip

  @type t :: %__MODULE__{
          id: String.t(),
          source_route_pattern_id: String.t(),
          route_id: String.t(),
          stops: [Stop.t()]
        }

  @typep route_pattern_with_stops :: %{
           id: String.t(),
           route_id: String.t(),
           stops: [Stop.t()]
         }

  defstruct [:id, :source_route_pattern_id, :route_id, :stops, :route_patterns_by_stop]

  @spec non_overlapping_segments([RoutePattern.t()], %{Stop.id() => Stop.t()}, %{
          Trip.id() => Trip.t()
        }) :: [t()]
  @doc """
  Get a list of non-overlapping RouteSegments for the list of route patterns.
  This will use parent stops wherever possible to detect when route patterns serve an overlapping set of stops.
  """
  def non_overlapping_segments(route_patterns, stops_by_id, trips_by_id) do
    route_patterns
    |> route_patterns_with_parent_stops(stops_by_id, trips_by_id)
    |> Enum.group_by(& &1.route_id)
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
    stop_ids =
      route_patterns_with_stops
      |> Enum.flat_map(& &1.stops)
      |> MapSet.new(& &1.id)

    build_non_overlapping_segments(route_patterns_with_stops, stop_ids, [])
  end

  @spec build_non_overlapping_segments([route_pattern_with_stops()], MapSet.t(Stop.id()), [t()]) ::
          [t()]
  # Build the list of RouteSegments. For each route pattern, consider only the stops on that route pattern
  # Which have not been included on an earlier RouteSegment.
  defp build_non_overlapping_segments(
         [route_pattern | rest],
         remaining_unseen_stop_ids,
         acc_segments
       ) do
    unseen_stop_ids_in_rp =
      route_pattern.stops
      |> Enum.filter(&MapSet.member?(remaining_unseen_stop_ids, &1.id))
      |> MapSet.new(& &1.id)

    new_segments =
      route_pattern
      |> unseen_stop_segments(unseen_stop_ids_in_rp)
      |> Enum.map(fn stops ->
        stop_segment_to_route_segment(route_pattern, stops)
      end)

    build_non_overlapping_segments(
      rest,
      MapSet.difference(remaining_unseen_stop_ids, unseen_stop_ids_in_rp),
      new_segments ++ acc_segments
    )
  end

  defp build_non_overlapping_segments([], _remaining_unseen_stops, acc_segments) do
    Enum.reverse(acc_segments)
  end

  @spec stop_segment_to_route_segment(route_pattern_with_stops(), [Stop.t()]) :: t()
  defp stop_segment_to_route_segment(route_pattern, stop_segment) do
    %__MODULE__{
      id: "#{List.first(stop_segment).id}-#{List.last(stop_segment).id}",
      source_route_pattern_id: route_pattern.id,
      route_id: route_pattern.route_id,
      stops: stop_segment
    }
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

defmodule MobileAppBackend.RouteBranching.StopDisambiguation do
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop
  alias MobileAppBackend.GlobalDataCache

  @type disambiguated_stop_id :: {Stop.id(), count :: pos_integer()}
  @type t :: [{RoutePattern.t(), [disambiguated_stop_id()]}]

  @spec build([Stop.id()], [RoutePattern.t()], GlobalDataCache.data()) :: t()
  def build(canon_stop_ids, patterns, global_data) do
    canon_stop_set = MapSet.new(canon_stop_ids)
    pattern_stops = Enum.map(patterns, &pattern_stops(&1, canon_stop_set, global_data))
    pattern_stops_with_counts = pattern_stops_with_counts(pattern_stops, canon_stop_ids)
    pattern_stops_with_counts
  end

  @spec pattern_stops(RoutePattern.t(), MapSet.t(Stop.id()), GlobalDataCache.data()) ::
          {RoutePattern.t(), [Stop.id()]}
  defp pattern_stops(pattern, canon_stops, global_data) do
    trip = global_data.trips[pattern.representative_trip_id]

    stops =
      trip.stop_ids
      |> Enum.map(&stop_or_parent_if_canon(&1, canon_stops, global_data))
      |> Enum.reject(&is_nil/1)

    {pattern, stops}
  end

  @spec stop_or_parent_if_canon(Stop.id(), MapSet.t(Stop.id()), GlobalDataCache.data()) ::
          Stop.id() | nil
  defp stop_or_parent_if_canon(stop_id, canon_stops, global_data) do
    if MapSet.member?(canon_stops, stop_id) do
      stop_id
    else
      parent = global_data.stops[stop_id].parent_station_id

      if MapSet.member?(canon_stops, parent) do
        parent
      end
    end
  end

  defmodule StopCountState do
    @moduledoc """
    Internal helper for `pattern_stops_with_counts/1`.

    Uses `List.myers_difference/2` to build up a list of disambiguated stops, so that repeated stops are correctly
    assigned the most optimal count possible.
    """
    @type t :: %__MODULE__{
            stops_with_counts: [{Stop.id(), count :: pos_integer()}],
            global_list_countless: [Stop.id()],
            global_list_countful: [{Stop.id(), count :: pos_integer()}],
            global_list_countful_remaining: [non_neg_integer()],
            counts: %{Stop.id() => pos_integer()}
          }
    defstruct [
      :stops_with_counts,
      :global_list_countless,
      :global_list_countful,
      :global_list_countful_remaining,
      :counts
    ]

    @spec process_edit_list(
            [{:eq | :ins | :del, [Stop.id()]}],
            [Stop.id()],
            [{Stop.id(), pos_integer()}],
            %{Stop.id() => pos_integer()}
          ) :: t()
    def process_edit_list(edit_list, global_list_countless, global_list_countful, counts) do
      edit_list
      |> Enum.reduce(
        new(global_list_countless, global_list_countful, counts),
        fn {action, sublist}, state ->
          apply_action(state, action, sublist)
        end
      )
    end

    # it would be possible to use the canon stop IDs as the initial global list, but sometimes the canon stop IDs are
    # not actually in topological order, which breaks a lot of things
    @spec new :: t()
    def new, do: new([], [], %{})

    @spec new([Stop.id()]) :: t()
    def new(global_list_countless) do
      global_list_countful = Enum.map(global_list_countless, &{&1, 1})
      counts = Map.new(global_list_countful)
      new(global_list_countless, global_list_countful, counts)
    end

    @spec new([Stop.id()], [{Stop.id(), pos_integer()}], %{Stop.id() => pos_integer()}) :: t()
    defp new(global_list_countless, global_list_countful, counts) do
      %__MODULE__{
        stops_with_counts: [],
        global_list_countless: global_list_countless,
        global_list_countful: global_list_countful,
        global_list_countful_remaining: global_list_countful,
        counts: counts
      }
    end

    @spec apply_action(t(), :eq | :ins | :del, [Stop.id()]) :: t()
    defp apply_action(state, action, sublist)

    defp apply_action(%__MODULE__{} = state, :eq, sublist) do
      {new_countful, remaining_countful} =
        Enum.split(state.global_list_countful_remaining, length(sublist))

      %__MODULE__{
        state
        | stops_with_counts: state.stops_with_counts ++ new_countful,
          global_list_countful_remaining: remaining_countful
      }
    end

    defp apply_action(%__MODULE__{} = state, :del, sublist) do
      remaining_countful = Enum.drop(state.global_list_countful_remaining, length(sublist))

      %__MODULE__{
        state
        | global_list_countful_remaining: remaining_countful
      }
    end

    defp apply_action(%__MODULE__{} = state, :ins, sublist) do
      {new_countful, counts} =
        Enum.map_reduce(sublist, state.counts, fn stop_id, counts ->
          {count, counts} =
            Map.get_and_update(counts, stop_id, fn
              nil -> {1, 1}
              x -> {x + 1, x + 1}
            end)

          {{stop_id, count}, counts}
        end)

      splice_point =
        length(state.global_list_countful) - length(state.global_list_countful_remaining)

      {countless_before, countless_after} = Enum.split(state.global_list_countless, splice_point)
      new_global_countless = countless_before ++ sublist ++ countless_after
      {countful_before, countful_after} = Enum.split(state.global_list_countful, splice_point)
      new_global_countful = countful_before ++ new_countful ++ countful_after

      %__MODULE__{
        stops_with_counts: state.stops_with_counts ++ new_countful,
        global_list_countless: new_global_countless,
        global_list_countful: new_global_countful,
        global_list_countful_remaining: state.global_list_countful_remaining,
        counts: counts
      }
    end
  end

  @doc false
  @spec pattern_stops_with_counts([{RoutePattern.t(), [Stop.id()]}], [Stop.id()]) :: t()
  def pattern_stops_with_counts(patterns_stops, canon_stop_ids) do
    {result, _} =
      patterns_stops
      |> Enum.sort_by(fn {pattern, stops} ->
        # we want to consider more typical patterns earlier, and also we want to consider longer patterns earlier
        # since longer patterns give us more context to use when disambiguating stops
        {RoutePattern.serialize_typicality!(pattern.typicality), -length(stops)}
      end)
      |> Enum.map_reduce(
        StopCountState.new(canon_stop_ids),
        fn {pattern, stops}, %StopCountState{} = state ->
          edit_list = List.myers_difference(state.global_list_countless, stops)

          inner_state =
            StopCountState.process_edit_list(
              edit_list,
              state.global_list_countless,
              state.global_list_countful,
              state.counts
            )

          {{pattern, inner_state.stops_with_counts},
           %StopCountState{
             state
             | global_list_countless: inner_state.global_list_countless,
               global_list_countful: inner_state.global_list_countful,
               counts: inner_state.counts
           }}
        end
      )

    result
  end
end

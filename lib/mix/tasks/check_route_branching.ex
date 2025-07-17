defmodule Mix.Tasks.CheckRouteBranching do
  @moduledoc """
  Previews the `MobileAppBackend.RouteBranching` logic, rendering graphs and diagrams for all non-trivial routes.
  """

  use Mix.Task
  @shortdoc "Checks route branching"
  @requirements ["app.start"]

  require Logger
  alias MBTAV3API.Repository
  alias MBTAV3API.Route
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.RouteBranching
  alias MobileAppBackend.RouteBranching.Segment
  alias MobileAppBackend.RouteBranching.SegmentGraph
  alias MobileAppBackend.RouteBranching.StopGraph

  defmodule UnusedWorkaroundsDetector do
    alias MobileAppBackend.RouteBranching.Workarounds

    # rather than define a second list of known workarounds here that will usually be stale, just read the source code
    # to know which workarounds are defined and should be used
    workarounds_module =
      __ENV__.file
      |> Path.split()
      |> Enum.take_while(&(&1 != "lib"))
      |> Path.join()
      |> Path.join("lib/mobile_app_backend/route_branching/workarounds.ex")
      |> File.read!()
      |> Code.string_to_quoted!()

    workarounds_cases =
      Macro.prewalker(workarounds_module)
      |> Enum.map(fn
        {:record_workaround_used, _, [route_id, direction_id]}
        when is_binary(route_id) and direction_id in [0, 1] ->
          {route_id, direction_id}

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    @expected MapSet.new(workarounds_cases)

    def start do
      {:ok, _} =
        Agent.start_link(
          fn ->
            MapSet.new()
          end,
          name: __MODULE__
        )

      :ok = :telemetry.attach(__MODULE__, [Workarounds, :used], &handle_event/4, nil)
    end

    def finish do
      actual = Agent.get(__MODULE__, & &1)
      Agent.stop(__MODULE__)

      if not MapSet.equal?(@expected, actual) do
        known_unused = @expected |> MapSet.difference(actual) |> Enum.sort()
        used_unknown = actual |> MapSet.difference(@expected) |> Enum.sort()

        raise "Workarounds have gone stale: known but not used #{inspect(known_unused)}, used but not known #{inspect(used_unknown)}"
      end
    end

    def handle_event(
          [Workarounds, :used],
          _measurements,
          %{route_id: route_id, direction_id: direction_id},
          _config
        ) do
      Agent.update(__MODULE__, &MapSet.put(&1, {route_id, direction_id}))
    end
  end

  @impl Mix.Task
  def run(args) do
    global_data = GlobalDataCache.get_data()

    route_ids = global_data.routes |> Map.keys() |> Enum.sort()

    route_ids =
      if args != [] do
        Enum.filter(route_ids, &(&1 in args))
      else
        route_ids
      end

    if args == [] do
      UnusedWorkaroundsDetector.start()
    end

    serious_issue =
      route_ids
      |> Enum.reject(&String.starts_with?(&1, "Shuttle"))
      |> Enum.flat_map(fn route_id ->
        route = global_data.routes[route_id]
        [{route, 0}, {route, 1}]
      end)
      |> Enum.map(fn {route, direction} ->
        run_single_case(route, direction, global_data)
      end)
      |> then(&(:error in &1))

    if args == [] do
      UnusedWorkaroundsDetector.finish()
    end

    if serious_issue do
      System.stop(1)
    end
  end

  defp run_single_case(route, direction, global_data) do
    caption =
      "#{route_label(route)} (#{route.id}) #{Enum.at(route.direction_names, direction)} (#{direction}) to #{Enum.at(route.direction_destinations, direction)}"

    {:ok, %{data: stops}} =
      Repository.stops(
        filter: [route: route.id, direction_id: direction],
        fields: [stop: [:id]]
      )

    stop_ids = stops |> Enum.map(fn stop -> stop.id end)

    {us, {stop_graph, segment_graph, segments}} =
      :timer.tc(fn ->
        RouteBranching.calculate(route.id, direction, stop_ids, global_data)
      end)

    if us > 5_000 do
      Logger.warning("#{caption} took #{us / 1000.0}ms")
    end

    if is_nil(segment_graph) or
         (:digraph.no_edges(stop_graph) > 0 and :digraph.no_vertices(segment_graph) > 1) do
      output_path = Path.join(["route-branching", route.id, "#{direction}"])
      File.mkdir_p!(output_path)

      stop_graph
      |> render_dot(Path.join(output_path, "stopGraph.png"), &visualize_stop_graph_node/2)

      segment_names = RouteBranching.get_name_candidates(route, direction)

      if is_nil(segment_graph) do
        Logger.error("segment_graph nil")
      else
        segment_graph
        |> render_dot(
          Path.join(output_path, "segmentGraph.png"),
          &visualize_segment_graph_node(&1, &2, segment_names)
        )
      end

      if is_nil(segments) do
        Logger.error("segments nil")
      else
        output_path
        |> Path.join("out.txt")
        |> File.write!([[caption, "\n"], visualize_segments(segments, global_data)])
      end

      if is_nil(segment_graph) or is_nil(segments) do
        :error
      else
        :ok
      end
    else
      :ok
    end
  end

  defp route_label(route)

  defp route_label(%Route{type: :bus, short_name: short_name}), do: short_name

  defp route_label(%Route{type: :commuter_rail, long_name: long_name}) do
    String.replace(long_name, "/", " / ")
  end

  defp route_label(%Route{long_name: long_name}), do: long_name

  defp visualize_stop_graph_node({stop_id, stop_count}, %StopGraph.Node{
         stop: stop,
         typicalities: typicalities
       }) do
    "#{stop.name} (#{stop_id}) ##{stop_count} [#{best_typicality(typicalities)}]"
  end

  defp visualize_segment_graph_node(
         _id,
         %SegmentGraph.Node{stops: stops, typicalities: typicalities},
         segment_name_candidates
       ) do
    names = Enum.map(stops, & &1.name)

    stop_names =
      if Enum.sum_by(names, &String.length/1) > 50 and length(names) > 2 do
        [List.first(names), "...#{length(names) - 2} stops...", List.last(names)]
      else
        names
      end
      |> Enum.join(", ")

    if name = Segment.get_segment_name(stops, segment_name_candidates) do
      "#{name} branch (#{stop_names})"
    else
      stop_names
    end <> " [#{best_typicality(typicalities)}]"
  end

  defp visualize_segments(segments, global_data) do
    Enum.flat_map(segments, fn segment ->
      non_typical =
        if segment.typical? do
          " "
        else
          "®"
        end

      for stop <- segment.stops do
        left = side_box(stop.stick_state.left, :left)
        right = side_box(stop.stick_state.right, :right)

        stop = global_data.stops[stop.stop_id]
        "#{non_typical} #{left}#{right} #{stop.name}"
      end
    end)
    |> Enum.join("\n")
  end

  defp best_typicality(typicalities) do
    [:typical, :deviation, :atypical, :diversion, :canonical_only]
    |> Enum.find(&MapSet.member?(typicalities, &1))
  end

  defp render_dot(graph, path, process_vertex_label) do
    nodes_dot =
      graph
      |> :digraph.vertices()
      |> Enum.map_join(fn id ->
        {_, label} = :digraph.vertex(graph, id)
        "#{dot_vertex_id(id)} [label=\"#{process_vertex_label.(id, label)}\"];\n"
      end)

    edges_dot =
      graph
      |> :digraph.edges()
      |> Enum.map_join(fn {from, to} ->
        "#{dot_vertex_id(from)} -> #{dot_vertex_id(to)};\n"
      end)

    dot_source = "digraph G {\n" <> nodes_dot <> edges_dot <> "}\n"
    dot_path = path <> ".dot"
    File.write!(dot_path, dot_source)

    Mix.Shell.cmd(
      {"dot", ["-T#{Path.extname(path) |> String.slice(1, 10)}", "-o#{path}", dot_path]},
      fn exit_status ->
        IO.puts(exit_status)
      end
    )
  end

  defp dot_vertex_id({stop_id, stop_count}) do
    Regex.replace(~r"\W", "s#{stop_id}-c#{stop_count}", "_")
  end

  defp side_box(state, side) do
    {left, right} =
      case side do
        :left ->
          {side_stop(state), side_cross(state)}

        :right ->
          {side_cross(state), side_stop(state)}
      end

    box_drawing(left, right, if(state.before, do: :light), if(state.after, do: :light))
  end

  defp side_stop(%Segment.StickSideState{current_stop: true}), do: :heavy
  defp side_stop(_), do: nil
  defp side_cross(%Segment.StickSideState{converging: true}), do: :light
  defp side_cross(%Segment.StickSideState{diverging: true}), do: :light
  defp side_cross(_), do: nil

  defp box_drawing(left, right, up, down)
  defp box_drawing(nil, nil, nil, nil), do: " "
  defp box_drawing(nil, nil, nil, :light), do: "╷"
  defp box_drawing(nil, nil, :light, nil), do: "╵"
  defp box_drawing(nil, nil, :light, :light), do: "│"
  defp box_drawing(nil, :light, nil, nil), do: "╶"
  defp box_drawing(nil, :light, nil, :light), do: "┌"
  defp box_drawing(nil, :light, :light, nil), do: "└"
  defp box_drawing(nil, :light, :light, :light), do: "├"
  defp box_drawing(nil, :heavy, nil, nil), do: "╺"
  defp box_drawing(nil, :heavy, nil, :light), do: "┍"
  defp box_drawing(nil, :heavy, :light, nil), do: "┕"
  defp box_drawing(nil, :heavy, :light, :light), do: "┝"
  defp box_drawing(:light, nil, nil, nil), do: "╴"
  defp box_drawing(:light, nil, nil, :light), do: "┐"
  defp box_drawing(:light, nil, :light, nil), do: "┘"
  defp box_drawing(:light, nil, :light, :light), do: "┤"
  defp box_drawing(:light, :heavy, nil, nil), do: "╼"
  defp box_drawing(:light, :heavy, nil, :light), do: "┮"
  defp box_drawing(:light, :heavy, :light, nil), do: "┶"
  defp box_drawing(:light, :heavy, :light, :light), do: "┾"
  defp box_drawing(:heavy, nil, nil, nil), do: "╸"
  defp box_drawing(:heavy, nil, nil, :light), do: "┑"
  defp box_drawing(:heavy, nil, :light, nil), do: "┙"
  defp box_drawing(:heavy, nil, :light, :light), do: "┥"
  defp box_drawing(:heavy, :light, nil, nil), do: "╾"
  defp box_drawing(:heavy, :light, nil, :light), do: "┭"
  defp box_drawing(:heavy, :light, :light, nil), do: "┵"
  defp box_drawing(:heavy, :light, :light, :light), do: "┽"
end

defmodule Mix.Tasks.CheckRouteBranching do
  @moduledoc """
  Previews the `MobileAppBackend.RouteBranching` logic, rendering graphs and diagrams for all non-trivial routes.

  Filter to a handful of routes and directions with `mix check_route_branching 33 Boat-F1:1 350:0`.

  Works best with GraphViz installed.

  Pass `--allow-unused-workarounds` to warn instead of erroring on unused workarounds.
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
  alias MobileAppBackend.RouteBranching.Segment.StickConnection
  alias MobileAppBackend.RouteBranching.SegmentGraph
  alias MobileAppBackend.RouteBranching.StopGraph

  defmodule UnusedWorkaroundsDetector do
    alias MobileAppBackend.RouteBranching.Workarounds

    # rather than define a second list of known workarounds here that will usually be stale, just read the source code
    # to know which workarounds are defined and should be used
    workarounds_path =
      __ENV__.file
      |> Path.split()
      |> Enum.take_while(&(&1 != "lib"))
      |> Path.join()
      |> Path.join("lib/mobile_app_backend/route_branching/workarounds.ex")

    @external_resource workarounds_path

    workarounds_module =
      workarounds_path
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

    def finish(opts) do
      allowed = opts[:allowed]
      actual = Agent.get(__MODULE__, & &1)
      Agent.stop(__MODULE__)

      if not MapSet.equal?(@expected, actual) do
        known_unused = @expected |> MapSet.difference(actual) |> Enum.sort()
        used_unknown = actual |> MapSet.difference(@expected) |> Enum.sort()

        message =
          "Workarounds have gone stale: known but not used #{inspect(known_unused)}, used but not known #{inspect(used_unknown)}"

        if allowed do
          Logger.warning(message)
          Path.join("route-branching", "stale-workarounds.txt") |> File.write!([message, ?\n])
        else
          raise message
        end
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
    {opts, args} = OptionParser.parse!(args, strict: [allow_unused_workarounds: :boolean])
    allow_unused_workarounds = opts[:allow_unused_workarounds]
    global_data = GlobalDataCache.get_data()

    routes_directions =
      global_data.routes |> Map.keys() |> Enum.sort() |> Enum.flat_map(&[{&1, 0}, {&1, 1}])

    routes_directions =
      if args != [] do
        Enum.filter(routes_directions, fn {route_id, direction_id} ->
          route_id in args or "#{route_id}:#{direction_id}" in args
        end)
      else
        Enum.reject(routes_directions, fn {route_id, _} ->
          String.starts_with?(route_id, "Shuttle")
        end)
      end

    if args == [] do
      UnusedWorkaroundsDetector.start()
    end

    serious_issue =
      routes_directions
      |> Enum.map(fn {route_id, direction} ->
        route = global_data.routes[route_id]
        run_single_case(route, direction, global_data)
      end)
      |> tap(&IO.puts("Checked route branching across #{length(&1)} routes and directions"))
      |> then(&(:error in &1))

    if args == [] do
      UnusedWorkaroundsDetector.finish(allowed: allow_unused_workarounds)
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
        |> File.write!([caption, "\n", visualize_segments(segments, global_data), "\n"])
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
         id,
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
    end <> " (#{elem(id, 0)} ##{elem(id, 1)}) [#{best_typicality(typicalities)}]"
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
        left = lane_box(stop, :left)
        center = lane_box(stop, :center)
        right = lane_box(stop, :right)

        stop = global_data.stops[stop.stop_id]
        "#{non_typical} #{left}#{center}#{right} #{stop.name}"
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
      |> Enum.sort()
      |> Enum.map_join(fn id ->
        {_, label} = :digraph.vertex(graph, id)
        "#{dot_vertex_id(id)} [label=\"#{process_vertex_label.(id, label)}\"];\n"
      end)

    edges_dot =
      graph
      |> :digraph.edges()
      |> Enum.sort()
      |> Enum.map_join(fn {from, to} ->
        "#{dot_vertex_id(from)} -> #{dot_vertex_id(to)};\n"
      end)

    dot_source = "digraph G {\n" <> nodes_dot <> edges_dot <> "}\n"
    dot_path = path <> ".dot"
    File.write!(dot_path, dot_source)

    try do
      Mix.Shell.cmd(
        {"dot", ["-T#{Path.extname(path) |> String.slice(1, 10)}", "-o#{path}", dot_path]},
        fn exit_status ->
          IO.puts(exit_status)
        end
      )
    rescue
      ErlangError -> :ok
    end
  end

  defp dot_vertex_id({stop_id, stop_count}) do
    Regex.replace(~r"\W", "s#{stop_id}-c#{stop_count}", "_")
  end

  defp lane_box(stop, lane) do
    left = lane_side(stop, lane, :left)

    right = lane_side(stop, lane, :right)

    up =
      Enum.any?(
        stop.connections,
        &(&1.from_lane == lane and &1.from_vpos == :top)
      )
      |> if(do: :light)

    down =
      Enum.any?(
        stop.connections,
        &(&1.to_lane == lane and &1.to_vpos == :bottom)
      )
      |> if(do: :light)

    box_drawing(left, right, up, down)
  end

  defp lane_side(stop, lane, side) do
    cond do
      stop.stop_lane == lane -> :heavy
      lane_side_cross(lane, side, stop.connections) -> :light
      true -> nil
    end
  end

  defp lane_side_cross(lane, side, connections) do
    Enum.any?(connections, fn %StickConnection{from_lane: from_lane, to_lane: to_lane} ->
      from_side? = lane_relative_side(lane, from_lane) == side
      to_side? = lane_relative_side(lane, to_lane) == side
      from_side? != to_side?
    end)
  end

  defp lane_relative_side(:left, :left), do: :center
  defp lane_relative_side(:left, :center), do: :right
  defp lane_relative_side(:left, :right), do: :right
  defp lane_relative_side(:center, :left), do: :left
  defp lane_relative_side(:center, :center), do: :center
  defp lane_relative_side(:center, :right), do: :right
  defp lane_relative_side(:right, :left), do: :left
  defp lane_relative_side(:right, :center), do: :left
  defp lane_relative_side(:right, :right), do: :center

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
  defp box_drawing(:light, :light, nil, nil), do: "─"
  defp box_drawing(:light, :light, nil, :light), do: "┬"
  defp box_drawing(:light, :light, :light, nil), do: "┴"
  defp box_drawing(:light, :light, :light, :light), do: "┼"
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
  defp box_drawing(:heavy, :heavy, nil, nil), do: "━"
  defp box_drawing(:heavy, :heavy, nil, :light), do: "┯"
  defp box_drawing(:heavy, :heavy, :light, nil), do: "┷"
  defp box_drawing(:heavy, :heavy, :light, :light), do: "┿"
end

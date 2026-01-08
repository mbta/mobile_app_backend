defmodule Mix.Tasks.TranspileKotlin do
  @moduledoc """
  Transpile Elixir to Kotlin
  """

  use Mix.Task
  @shortdoc "Transpile Elixir to Kotlin"

  defmodule Memory do
    @nothing {:nothing, System.unique_integer()}

    def put(k, v), do: Process.put({__MODULE__, k}, v)

    def pop(k, default \\ nil) do
      result =
        case Process.get({__MODULE__, k}, default) do
          @nothing -> default
          result -> result
        end

      Process.put(k, @nothing)
      result
    end
  end

  @impl Mix.Task
  def run(_args) do
    file = "lib/mobile_app_backend/alerts/alert_summary.ex"
    code = file |> File.read!() |> Code.string_to_quoted!(file: file)
    output = kotlinize(code, [])
    IO.puts(output)
  end

  @spec kotlinize(Macro.t(), keyword()) :: IO.chardata()
  defp kotlinize(code, context)

  defp kotlinize({:defmodule, _, [alias, [{:do, {:__block__, [], body}}]]}, context) do
    indent = Keyword.get(context, :indent, [])

    sealed_extends =
      case Keyword.fetch(context, :sealed_extends) do
        {:ok, superclass} -> [": ", superclass, "()"]
        :error -> []
      end

    {module_name, _} = Code.eval_quoted(alias)
    decl_name = Module.split(module_name) |> List.last()

    elixir_typespec =
      Enum.find_value(body, fn
        {:@, _, [{:type, _, [{:"::", _, [{:t, _, nil}, typespec]}]}]} -> typespec
        _ -> nil
      end)

    decl =
      case elixir_typespec do
        {:%, _, [{:__MODULE__, _, nil}, {:%{}, _, properties}]} ->
          Enum.map(properties, fn {name, type} ->
            [indent, "    val ", kotlinize_identifier(name), ": ", kotlinize_type(type), ",\n"]
          end)

        {:|, _, _variants} ->
          nil
      end

    {decl, context} =
      Enum.find_value(body, fn
        {:defstruct, _, [[]]} ->
          {[indent, "public data object ", to_string(decl_name)], context}

        {:defstruct, _, [_]} ->
          {[indent, "public data class ", to_string(decl_name), "(\n", decl, indent, ")"],
           context}

        {:alias, _, _} ->
          nil

        {:defmodule, _, _} ->
          nil

        {:defprotocol, _, _} ->
          nil

        {:@, _, [{:derive, _, _}]} ->
          nil

        {:@, _, [{:type, _, [{:"::", _, [{:t, _, nil}, {:|, _, _variants}]}]}]} ->
          {[indent, "public sealed class ", to_string(decl_name)],
           Keyword.put(context, :sealed_extends, to_string(decl_name))}

        {:@, _, [{:type, _, _}]} ->
          nil

        x ->
          dbg(x)
      end)

    package_decl =
      if indent == [] do
        "package com.mbta.tid.mbta_app.transpiled\n\n"
      else
        []
      end

    context =
      context
      |> Keyword.put(:indent, [indent, "    "])
      |> Keyword.put(:containing_type, to_string(decl_name))

    [package_decl, decl || [], sealed_extends, " {\n", kotlinize(body, context), indent, "}\n"]
  end

  defp kotlinize({:defprotocol, _, _}, _), do: []

  defp kotlinize({:@, _, [{:doc, _, [doc]}]}, context) do
    indent = Keyword.get(context, :indent, [])
    line_limit = 80
    prefix_size = (IO.chardata_to_string(indent) |> String.length()) + 3
    doc_limit = line_limit - prefix_size

    lines =
      doc
      |> String.split()
      |> Enum.chunk_while(
        "",
        fn element, acc ->
          new_line =
            case acc do
              "" -> element
              _ -> acc <> " " <> element
            end

          if String.length(new_line) > doc_limit do
            {:cont, [indent, " * ", acc, "\n"], element}
          else
            {:cont, new_line}
          end
        end,
        fn
          "" -> {:cont, ""}
          x -> {:cont, [indent, " * ", x, "\n"], ""}
        end
      )

    [indent, "/**\n", lines, indent, " */\n"]
  end

  defp kotlinize({:alias, _, _}, _), do: []
  defp kotlinize({:@, _, [{:type, _, [{:"::", _, [{:t, _, nil}, _]}]}]}, _), do: []
  defp kotlinize({:@, _, [{:derive, _, [{:__aliases__, _, [:JSON, :Encoder]}]}]}, _), do: []
  defp kotlinize({:@, _, [{:derive, _, [{:__aliases__, _, [:Jason, :Encoder]}]}]}, _), do: []
  defp kotlinize({:@, _, [{:derive, _, [{:__aliases__, _, [:PolymorphicJson]}]}]}, _), do: []

  defp kotlinize({:@, _, [{:spec, _, [{:"::", _, [{name, _, args}, return_type]}]}]}, _) do
    Memory.put({:spec, name}, {args, return_type})
    []
  end

  defp kotlinize({:defstruct, _, _}, _), do: []

  defp kotlinize({:@, _, [{name, _, [value]}]}, context) do
    indent = Keyword.get(context, :indent, [])

    [
      indent,
      "private static val ",
      kotlinize_identifier(name),
      " = ",
      kotlinize_literal(value, indent: indent),
      "\n"
    ]
  end

  defp kotlinize({:@, _, [{name, _, nil}]}, _context) do
    kotlinize_identifier(name)
  end

  defp kotlinize({def_type, _, [{name, _, args}, [{:do, block}]]}, context)
       when def_type in [:def, :defp] do
    indent = Keyword.get(context, :indent, [])

    {args_spec, return_spec} =
      Memory.pop({:spec, name}, {Stream.cycle([{:term, [], []}]), {:term, [], []}})

    args_decl =
      Enum.zip_with(args, args_spec, fn arg, arg_spec ->
        {arg, default} =
          case arg do
            {arg, _, nil} -> {arg, []}
            {:\\, _, [{arg, _, nil}, default]} -> {arg, [" = ", kotlinize_literal(default)]}
          end

        [
          indent,
          "    ",
          kotlinize_identifier(arg),
          ": ",
          kotlinize_type(arg_spec, context),
          default,
          ",\n"
        ]
      end)

    visibility =
      case def_type do
        :def -> "public"
        :defp -> "private"
      end

    [
      indent,
      visibility,
      " static fun ",
      kotlinize_identifier(name),
      "(\n",
      args_decl,
      indent,
      "): ",
      kotlinize_type(return_spec, context),
      " = ",
      kotlinize(block, context),
      "\n"
    ]
  end

  defp kotlinize(
         {{:., _, [{:__aliases__, _, [:Map]}, :filter]}, _, [{arg, _, nil}, lambda]},
         context
       ) do
    [kotlinize_identifier(arg), ".filter ", kotlinize(lambda, context), "\n"]
  end

  defp kotlinize(
         {{:., _, [{:__aliases__, _, [:Enum]}, :any?]}, _, [{arg, _, nil}, lambda]},
         context
       ) do
    [kotlinize_identifier(arg), ".any ", kotlinize(lambda, context), "\n"]
  end

  defp kotlinize(
         {{:., _, [{:__aliases__, _, [:Enum]}, :all?]}, _, [{arg, _, nil}, lambda]},
         context
       ) do
    [kotlinize_identifier(arg), ".all ", kotlinize(lambda, context), "\n"]
  end

  defp kotlinize(
         {{:., _, [{:__aliases__, _, [:Enum]}, :map]}, _, [{arg, _, nil}, lambda]},
         context
       ) do
    [kotlinize_identifier(arg), ".map ", kotlinize(lambda, context), "\n"]
  end

  defp kotlinize(
         {{:., _, [{:__aliases__, _, [:Enum]}, :join]}, _, [{arg, _, nil}, joiner]},
         context
       ) do
    [kotlinize_identifier(arg), ".joinToString(", kotlinize(joiner, context), ")"]
  end

  defp kotlinize(
         {{:., _, [{:__aliases__, _, [:Stop]}, :parent_id]}, _, [stop]},
         context
       ) do
    [kotlinize(stop, context), ".resolveParent(global)?.id"]
  end

  defp kotlinize({{:., _, [Access, :get]}, _, [container, key]}, context) do
    [kotlinize(container, context), "[", kotlinize(key, context), "]"]
  end

  defp kotlinize(
         {:__block__, _, operations},
         context
       ) do
    indent = Keyword.get(context, :indent, [])
    context = Keyword.put(context, :indent, [indent, "    "])
    ["run {\n", indent, "    ", kotlinize(operations, context), indent, "}\n"]
  end

  defp kotlinize({:if, _, [condition, [{:do, true_block}, {:else, false_block}]]}, context) do
    indent = Keyword.get(context, :indent, [])
    context = Keyword.put(context, :indent, [indent, "    "])

    [
      indent,
      "if (",
      kotlinize(condition, context),
      indent,
      ") {\n",
      kotlinize(true_block, context),
      indent,
      "} else {\n",
      indent,
      "    ",
      kotlinize(false_block, context),
      indent,
      "}\n"
    ]
  end

  defp kotlinize({:&, _, [1]}, _context), do: "it"
  defp kotlinize({:&, _, [body]}, context), do: ["{ ", kotlinize(body, context), " }"]

  defp kotlinize({:in, _, [needle, haystack]}, context),
    do: [kotlinize(needle, context), " in ", kotlinize(haystack, context)]

  defp kotlinize({:fn, _, [{:->, _, [args, body]}]}, context) do
    indent = Keyword.get(context, :indent, [])
    context = Keyword.put(context, :indent, [indent, "    "])

    args =
      Enum.map_intersperse(args, ", ", fn
        {{dest1, _, nil}, {dest2, _, nil}} ->
          ["(", kotlinize_identifier(dest1), ", ", kotlinize_identifier(dest2), ")"]

        {arg, _, nil} ->
          kotlinize_identifier(arg)
      end)

    ["{ ", args, " ->\n", indent, "    ", kotlinize(body, context), "\n", indent, "}"]
  end

  defp kotlinize({arg1, arg2}, context) do
    indent = Keyword.get(context, :indent, [])
    context = Keyword.put(context, :indent, [indent, "    "])
    ["Pair(\n", indent, kotlinize(arg1, context), ",\n", indent, kotlinize(arg2, context), ")"]
  end

  defp kotlinize({:not, _, [arg]}, context) do
    ["!", kotlinize(arg, context)]
  end

  defp kotlinize({:and, _, [arg1, arg2]}, context) do
    [kotlinize(arg1, context), " && ", kotlinize(arg2, context)]
  end

  defp kotlinize({:++, _, [arg1, arg2]}, context) do
    [kotlinize(arg1, context), " + ", kotlinize(arg2, context)]
  end

  defp kotlinize({:%, _, [struct, {:%{}, _, props}]}, context) do
    indent = Keyword.get(context, :indent, [])
    context = Keyword.put(context, :indent, [indent, "    "])
    {struct, _} = struct |> Code.eval_quoted()
    struct = Macro.inspect_atom(:literal, struct)

    props =
      Enum.map(props, fn {name, value} ->
        [indent, kotlinize_identifier(name), " = ", kotlinize(value, context), ",\n"]
      end)

    [struct, "(\n", props, indent, ")"]
  end

  defp kotlinize({:=, _, [{name, _, nil}, value]}, context) do
    ["val ", kotlinize_identifier(name), " = ", kotlinize(value, context), "\n"]
  end

  defp kotlinize({binary_op, _, [arg1, arg2]}, context) when binary_op in [:>, :!=, :==, :<] do
    [kotlinize(arg1, context), " ", to_string(binary_op), " ", kotlinize(arg2, context)]
  end

  defp kotlinize({{:., _, [obj, prop]}, metadata, []}, context) when is_atom(prop) do
    case Keyword.fetch!(metadata, :no_parens) do
      true -> [kotlinize(obj, context), ".", kotlinize_identifier(prop)]
    end
  end

  defp kotlinize({:length, _, [arg]}, context), do: [kotlinize(arg, context), ".size"]

  defp kotlinize({:hd, _, [arg]}, context), do: [kotlinize(arg, context), ".first"]

  defp kotlinize(val, _) when is_binary(val) when is_integer(val), do: kotlinize_literal(val)

  defp kotlinize({name, _, nil}, _context) when is_atom(name), do: kotlinize_identifier(name)

  defp kotlinize({:case, _, [operand, [{:do, cases}]]}, context) do
    indent = Keyword.get(context, :indent, [])
    context = Keyword.put(context, :indent, [indent, "    "])

    cases =
      Enum.map(cases, fn {:->, _, [lhs, rhs]} ->
        [indent, "    ", kotlinize(lhs, context), " -> ", kotlinize(rhs, context), "\n"]
      end)

    ["when (", kotlinize(operand, context), ") {\n", cases, indent, "}"]
  end

  defp kotlinize(:typical, _), do: "RoutePattern.Typicality.Typical"

  defp kotlinize(code, context) when is_list(code) do
    Enum.map(code, &kotlinize(&1, context))
  end

  defp kotlinize(code, context) do
    dbg()
    []
  end

  @spec kotlinize_type(Macro.t(), keyword()) :: IO.chardata()
  defp kotlinize_type(type, context \\ [])

  defp kotlinize_type({{:., _, [module, type]}, _, []}, _) do
    {module, _} = Code.eval_quoted(module)

    type =
      case type do
        :t -> module
        name -> Module.concat([module, Macro.camelize(to_string(name))])
      end

    Macro.inspect_atom(:literal, type)
  end

  defp kotlinize_type({:|, _, [t, nil]}, context), do: [kotlinize_type(t, context), "?"]

  defp kotlinize_type({:|, _, [0, 1]}, _), do: "Int"

  defp kotlinize_type({:term, _, []}, _), do: "Any?"

  defp kotlinize_type({:t, _, []}, context) do
    containing_type = Keyword.fetch!(context, :containing_type)
    containing_type
  end

  defp kotlinize_type([t], context), do: ["List<", kotlinize_type(t, context), ">"]

  defp kotlinize_type(type, context) do
    dbg()
    []
  end

  @spec kotlinize_literal(Macro.t(), Keyword.t()) :: IO.chardata()
  defp kotlinize_literal(literal, context \\ [])

  defp kotlinize_literal([], _), do: "emptyList()"

  defp kotlinize_literal(literal, context) when is_list(literal) do
    indent = Keyword.get(context, :indent, [])

    [
      "listOf(\n",
      Enum.map(
        literal,
        &[
          indent,
          "    ",
          kotlinize_literal(&1, Keyword.put(context, :indent, [indent, "    "])),
          ",\n"
        ]
      ),
      indent,
      ")"
    ]
  end

  defp kotlinize_literal({left, right}, context) do
    ["Pair(", kotlinize_literal(left, context), ", ", kotlinize_literal(right, context), ")"]
  end

  defp kotlinize_literal(literal, _) when is_binary(literal) when is_integer(literal) do
    Macro.to_string(literal)
  end

  defp kotlinize_literal({:%{}, _, values}, context) do
    indent = Keyword.get(context, :indent, [])

    [
      "mapOf(\n",
      Enum.map(values, fn {k, v} ->
        context = Keyword.put(context, :indent, [indent, "    "])

        [
          indent,
          "    ",
          kotlinize_literal(k, context),
          " to ",
          kotlinize_literal(v, context),
          ",\n"
        ]
      end),
      indent,
      ")"
    ]
  end

  defp kotlinize_literal(nil, _), do: "null"

  defp kotlinize_literal(literal, context) do
    dbg()
    []
  end

  defp kotlinize_identifier(:_), do: "_"

  defp kotlinize_identifier(name) do
    {first, rest} = name |> to_string() |> Macro.camelize() |> String.split_at(1)
    String.downcase(first) <> rest
  end
end

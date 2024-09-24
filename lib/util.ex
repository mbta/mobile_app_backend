defmodule Util do
  @doc """
  Define some helper types and functions for working with enums returned from the V3 API.

  ## Examples

      iex> quote do
      ...>   Util.declare_enum(:lifecycle,
      ...>     new: "NEW",
      ...>     ongoing: "ONGOING",
      ...>     ongoing_upcoming: "ONGOING_UPCOMING",
      ...>     upcoming: "UPCOMING"
      ...>   )
      ...> end
      ...> |> Macro.expand_once(__ENV__)
      ...> |> Macro.to_string()
      ...> |> String.split("\\n")
      [
        "@type lifecycle :: :new | :ongoing | :ongoing_upcoming | :upcoming",
        "@type raw_lifecycle :: String.t()",
        "@spec parse_lifecycle(raw_lifecycle()) :: lifecycle()",
        "def parse_lifecycle(lifecycle) do",
        "  case lifecycle do",
        "    \\"NEW\\" -> :new",
        "    \\"ONGOING\\" -> :ongoing",
        "    \\"ONGOING_UPCOMING\\" -> :ongoing_upcoming",
        "    \\"UPCOMING\\" -> :upcoming",
        "  end",
        "end",
        "",
        "@spec parse_lifecycle(raw_lifecycle(), lifecycle()) :: lifecycle()",
        "def parse_lifecycle(lifecycle, default) do",
        "  case lifecycle do",
        "    \\"NEW\\" -> :new",
        "    \\"ONGOING\\" -> :ongoing",
        "    \\"ONGOING_UPCOMING\\" -> :ongoing_upcoming",
        "    \\"UPCOMING\\" -> :upcoming",
        "    _ -> default",
        "  end",
        "end",
        "",
        "@spec serialize_lifecycle(lifecycle()) :: raw_lifecycle()",
        "def serialize_lifecycle(lifecycle) do",
        "  case lifecycle do",
        "    :new -> \\"NEW\\"",
        "    :ongoing -> \\"ONGOING\\"",
        "    :ongoing_upcoming -> \\"ONGOING_UPCOMING\\"",
        "    :upcoming -> \\"UPCOMING\\"",
        "  end",
        "end"
      ]

      iex> quote do
      ...>   Util.declare_enum(:x, a: 0, b: 1)
      ...> end
      ...> |> Macro.expand_once(__ENV__)
      ...> |> Macro.to_string()
      ...> |> String.split("\\n")
      [
        "@type x :: :a | :b",
        "@type raw_x :: 0 | 1",
        "@spec parse_x(raw_x()) :: x()",
        "def parse_x(x) do",
        "  case x do",
        "    0 -> :a",
        "    1 -> :b",
        "  end",
        "end",
        "",
        "@spec parse_x(raw_x(), x()) :: x()",
        "def parse_x(x, default) do",
        "  case x do",
        "    0 -> :a",
        "    1 -> :b",
        "    _ -> default",
        "  end",
        "end",
        "",
        "@spec serialize_x(x()) :: raw_x()",
        "def serialize_x(x) do",
        "  case x do",
        "    :a -> 0",
        "    :b -> 1",
        "  end",
        "end"
      ]

      iex> quote do
      ...>   Util.declare_enum(:a, x: "X", y: nil)
      ...> end
      ...> |> Macro.expand_once(__ENV__)
      ...> |> Macro.to_string()
      ...> |> String.replace("\\n\\n", "\\n#\\n")
      ...> |> then(&(&1 <> "\\n"))
      \"\"\"
      @type a :: :x | :y
      @type raw_a :: String.t() | nil
      @spec parse_a(raw_a()) :: a()
      def parse_a(a) do
        case a do
          "X" -> :x
          nil -> :y
        end
      end
      #
      @spec parse_a(raw_a(), a()) :: a()
      def parse_a(a, default) do
        case a do
          "X" -> :x
          nil -> :y
          _ -> default
        end
      end
      #
      @spec serialize_a(a()) :: raw_a()
      def serialize_a(a) do
        case a do
          :x -> "X"
          :y -> nil
        end
      end
      \"\"\"
  """
  defmacro declare_enum(name, values) do
    {values, _} = Code.eval_quoted(values, [], __CALLER__)

    type_spec =
      values
      |> Enum.map(fn {value, _raw_value} -> typeof(value) end)
      |> Enum.uniq()
      |> type_union()

    raw_type_spec =
      values
      |> Enum.map(fn {_value, raw_value} -> typeof(raw_value) end)
      |> Enum.uniq()
      |> type_union()

    type_name = Macro.var(name, nil)
    parse_fn = :"parse_#{name}"
    serialize_fn = :"serialize_#{name}"
    method_arg = Macro.var(name, __MODULE__)
    default_arg = Macro.var(:default, __MODULE__)
    raw_type = :"raw_#{name}"
    raw_type_name = Macro.var(raw_type, nil)

    parse_clauses =
      Enum.map(values, fn {value, raw_value} ->
        [{:->, _, _} = clause] =
          quote do
            unquote(raw_value) -> unquote(value)
          end

        clause
      end)

    parse_default_clause =
      quote do
        _ -> unquote(default_arg)
      end

    serialize_clauses =
      Enum.map(values, fn {value, raw_value} ->
        [{:->, _, _} = clause] =
          quote do
            unquote(value) -> unquote(raw_value)
          end

        clause
      end)

    parse_body = {:case, [], [method_arg, [do: parse_clauses]]}
    parse_default_body = {:case, [], [method_arg, [do: parse_clauses ++ parse_default_clause]]}
    serialize_body = {:case, [], [method_arg, [do: serialize_clauses]]}

    quote do
      @type unquote(type_name) :: unquote(type_spec)
      @type unquote(raw_type_name) :: unquote(raw_type_spec)

      @spec unquote(parse_fn)(unquote(raw_type)()) :: unquote(name)()
      def unquote(parse_fn)(unquote(method_arg)) do
        unquote(parse_body)
      end

      @spec unquote(parse_fn)(unquote(raw_type)(), unquote(name)()) :: unquote(name)()
      def unquote(parse_fn)(unquote(method_arg), unquote(default_arg)) do
        unquote(parse_default_body)
      end

      @spec unquote(serialize_fn)(unquote(name)()) :: unquote(raw_type)()
      def unquote(serialize_fn)(unquote(method_arg)) do
        unquote(serialize_body)
      end
    end
  end

  defp typeof(x) when is_atom(x) when is_integer(x), do: x
  defp typeof(x) when is_binary(x), do: quote(do: String.t())

  @doc """
  Builds enum values based on common patterns in the V3 API.

  ## Examples

      iex> Util.enum_values(:uppercase_string, [:new, :ongoing, :ongoing_upcoming, :upcoming])
      [new: "NEW", ongoing: "ONGOING", ongoing_upcoming: "ONGOING_UPCOMING", upcoming: "UPCOMING"]

      iex> Util.enum_values(:index, [:light_rail, :heavy_rail, :commuter_rail, :bus, :ferry])
      [light_rail: 0, heavy_rail: 1, commuter_rail: 2, bus: 3, ferry: 4]
  """
  def enum_values(transform, values) do
    case transform do
      :uppercase_string -> Enum.map(values, &{&1, String.upcase(Atom.to_string(&1))})
      :index -> Enum.with_index(values)
    end
  end

  @doc """
  Parses a value as an `America/New_York` datetime.

  ## Examples

      iex> Util.parse_datetime!("2024-02-02T10:45:52-05:00")
      #DateTime<2024-02-02 10:45:52-05:00 EST America/New_York>
  """
  @spec parse_datetime!(String.t()) :: DateTime.t()
  def parse_datetime!(data) do
    {:ok, datetime, _} = DateTime.from_iso8601(data)
    DateTime.shift_zone!(datetime, "America/New_York")
  end

  @doc """
  Parses an optional value as an `America/New_York` datetime.

  ## Examples

      iex> Util.parse_optional_datetime!(nil)
      nil

      iex> Util.parse_optional_datetime!("2024-02-02T10:45:52-05:00")
      #DateTime<2024-02-02 10:45:52-05:00 EST America/New_York>
  """
  @spec parse_optional_datetime!(String.t() | nil) :: DateTime.t() | nil
  def parse_optional_datetime!(data)
  def parse_optional_datetime!(nil), do: nil
  def parse_optional_datetime!(data), do: parse_datetime!(data)

  @doc """
  Constructs a union out of a list of types.

  ## Examples

      iex> values = quote(do: [Foo.t(), Bar.t(), Baz.t()])
      iex> Util.type_union(values) |> Macro.to_string()
      "Foo.t() | Bar.t() | Baz.t()"

      iex> options = [:a, :b, :c]
      iex> quote do
      ...>   @type test :: unquote(Util.type_union(options))
      ...> end |> Macro.to_string()
      "@type test :: :a | :b | :c"
  """
  def type_union(args) do
    # must reverse args because | is right-associative

    args
    |> Enum.reverse()
    |> Enum.reduce(fn t, acc -> quote(do: unquote(t) | unquote(acc)) end)
  end

  @doc """
  Converts a local time into a GTFS {service date, HH:MM}.

  ## Examples

      iex> import Test.Support.Sigils
      iex> Util.datetime_to_gtfs(~B[2024-03-12 10:55:39])
      ~D[2024-03-12]
      iex> Util.datetime_to_gtfs(~B[2024-03-12 00:19:03])
      ~D[2024-03-11]
      iex> Util.datetime_to_gtfs(~B[2024-03-12 01:23:45])
      ~D[2024-03-11]
      iex> Util.datetime_to_gtfs(~B[2024-03-12 02:11:00])
      ~D[2024-03-12]
  """
  @spec datetime_to_gtfs(DateTime.t()) :: Date.t()
  def datetime_to_gtfs(%DateTime{hour: hour, time_zone: "America/New_York"} = datetime) do
    date = DateTime.to_date(datetime)

    if hour in [0, 1] do
      Date.add(date, -1)
    else
      date
    end
  end
end

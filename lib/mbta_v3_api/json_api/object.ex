defmodule MBTAV3API.JsonApi.Object do
  @moduledoc """
  Shared logic for all objects that can be represented as JSON:API resources.
  """
  alias MBTAV3API.JsonApi
  alias MBTAV3API.Route

  @doc """
  JSON:API type name for the object this module represents.
  """
  @callback jsonapi_type :: atom()
  @doc """
  List of fields to include by default in JSON:API calls. Should match the `defstruct/1` names and orders.
  """
  @callback fields :: [atom()]
  @doc """
  Map of related objects that can be included to their struct modules. `%{trip: MBTAV3API.Trip, stops: MBTAV3API.Stop, parent_station: MBTAV3API.Stop}`, etc. Names should match `defstruct/1`.
  """
  @callback includes :: %{atom() => module()}
  @doc """
  If needed, a list of virtual fields that should be included at the end of `defstruct/1` but not loaded from the API.
  """
  @callback virtual_fields :: [atom()]

  @doc """
  If needed, a custom serialize function.

  To turn `filter: [route_type: :bus]` into `"filter[route_type]" => 3`,
  ```
  def serialize_filter_value(:route_type, :bus), do: 3
  ```
  """
  @callback serialize_filter_value(
              field_name :: atom(),
              provided_value :: JsonApi.FilterValue.t()
            ) :: JsonApi.FilterValue.t()
  @optional_callbacks virtual_fields: 0, serialize_filter_value: 2

  @doc """
  Sets up the `JsonApi.Object` behaviour with compile-time validation of `c:fields/0` and `c:includes/0` against the `defstruct/1`.
  Also defines `c:jsonapi_type/0` based on the module name to invert `module_for/1`.

  Expects the `defstruct` to be `[:id, ...field names..., ...related object ID fields...]`.
  Field names should match the order in `c:fields/1` (which should probably be alphabetized) and related object names should be alphabetized and _id or _ids.

  By default, expects the fields to match the struct keys exactly, and expects singular includes to match with _id and plurals with _ids.
  If renaming a field at parse time, `use MBTAV3API.JsonApi.Object, renames: %{jsonapi_name => struct_name}`.
  For included objects, the rename will be applied before adding _id, so the rename should not include _id.
  """
  defmacro __using__(opts) do
    renames = Keyword.get(opts, :renames, quote(do: %{}))

    jsonapi_type =
      __CALLER__.module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()

    quote do
      alias MBTAV3API.JsonApi

      @behaviour JsonApi.Object

      Module.put_attribute(__MODULE__, :jsonapi_object_renames, unquote(renames))

      @type id :: String.t()

      @impl JsonApi.Object
      def jsonapi_type, do: unquote(jsonapi_type)

      @after_compile JsonApi.Object
    end
  end

  @doc """
  Retrieves the module for the given JSON:API type.
  """
  @spec module_for(atom() | String.t()) :: module()
  def module_for(type)

  @doc """
  Converts the given JSON:API type into its plural form.
  """
  @spec plural_type(atom()) :: atom()
  def plural_type(type)

  types = [
    :alert,
    :facility,
    :line,
    :prediction,
    :route,
    :route_pattern,
    :schedule,
    :service,
    :shape,
    :stop,
    :trip,
    :vehicle
  ]

  @plural_types Map.new(
                  types,
                  &{&1,
                   case &1 do
                     :facility -> :facilities
                     _ -> :"#{&1}s"
                   end}
                )

  modules =
    for type <- types do
      module = Module.concat(MBTAV3API, Macro.camelize(to_string(type)))

      def module_for(unquote(type)), do: unquote(module)
      def module_for(unquote("#{type}")), do: unquote(module)

      def plural_type(unquote(type)), do: unquote(@plural_types[type])

      @type unquote(Macro.var(:"#{type}_map", __MODULE__)) :: %{String.t() => unquote(module).t()}

      module
    end

  module_types = Enum.map(modules, fn module -> quote(do: unquote(module).t()) end)

  @type t :: unquote(Util.type_union(module_types))

  map_elements =
    Enum.map(types, fn type ->
      map_type = Macro.var(:"#{type}_map", __MODULE__)

      {:%{}, _, [map_element]} =
        quote do
          %{required(unquote(@plural_types[type])) => unquote(map_type)}
        end

      map_element
    end)

  @typedoc """
  A map of objects parsed from a response, grouped by type and by id.

  Types are always present, even if there is no data, so matching on %{stops: stops} will always work.
  """
  @type full_map :: %{unquote_splicing(map_elements)}

  @empty_full_map types |> Enum.map(&@plural_types[&1]) |> Map.from_keys(%{})

  @spec to_full_map([t()]) :: full_map()
  def to_full_map(objects) do
    Enum.reduce(objects, @empty_full_map, fn %module{id: id} = item, map ->
      put_in(map, [plural_type(module.jsonapi_type()), id], item)
    end)
  end

  @spec merge_full_map(full_map(), full_map()) :: full_map()
  def merge_full_map(objects1, objects2) do
    Map.merge(objects1, objects2, fn _type, map1, map2 -> Map.merge(map1, map2) end)
  end

  modules_guard =
    modules
    |> Enum.map(fn module ->
      # Due to macro hygiene, `quote(do: is_struct(x, unquote(module)))` will fail
      # because there is no variable `x`. To reference the yet-to-be-defined guard parameter,
      # we need to bypass macro hygiene entirely.
      quote(do: is_struct(var!(x), unquote(module)))
    end)
    |> Enum.reduce(fn clause, acc -> quote(do: unquote(acc) or unquote(clause)) end)

  guard_doctest =
    Enum.zip(types, modules)
    |> Enum.map_join(
      "\n",
      fn {type, module} ->
        "    iex> #{type} = %#{Macro.to_string(module)}{}\n    iex> MBTAV3API.JsonApi.Object.is_json_object(#{type})\n    true"
      end
    )

  @doc """
  Checks whether or not the given value is an instance of a JSON:API object.

  ## Examples

  #{guard_doctest}
      iex> MBTAV3API.JsonApi.Object.is_json_object(~D[2024-02-02])
      false
  """
  defguard is_json_object(x) when unquote(modules_guard)

  @doc """
  Parses a `t:JsonApi.Item.t/0` into a struct of the right type, or preserves a `t:JsonApi.Reference.t/0` as-is.

  Preserving references is important for correctly handing stream remove messages.
  """
  @spec parse!(JsonApi.Item.t(), [JsonApi.Item.t()]) :: t()
  @spec parse!(JsonApi.Reference.t(), [JsonApi.Item.t()]) :: JsonApi.Reference.t()
  def parse!(item, included \\ [])
  def parse!(%JsonApi.Item{type: "route"} = item, included), do: Route.parse!(item, included)
  def parse!(%JsonApi.Item{type: type} = item, _included), do: module_for(type).parse!(item)
  def parse!(%JsonApi.Reference{} = ref, _included), do: ref

  @doc """
  Parses a list of `t:JsonApi.Item.t/0`s into structs of the right type, discarding any which cannot be parsed.

  Preserves `t:JsonApi.Reference.t/0`s as-is, which is important for correctly handing stream remove messages.
  """
  @spec parse_all_discarding_failures([JsonApi.Item.t()], [JsonApi.Item.t()]) :: [t()]
  @spec parse_all_discarding_failures(
          [JsonApi.Item.t() | JsonApi.Reference.t()],
          [JsonApi.Item.t()]
        ) :: [t() | JsonApi.Reference.t()]
  def parse_all_discarding_failures(items, included \\ []) do
    # Kotlin's mapNotNull would be really nice here, but alas, we don't have it.
    Enum.flat_map(items, fn raw_item ->
      try do
        [parse!(raw_item, included)]
      rescue
        ex ->
          Sentry.capture_exception(ex, stacktrace: __STACKTRACE__)
          []
      end
    end)
  end

  @doc """
  Gets the `id` of a single `JsonApi.Reference`.

  Useful for parsing relationships where only a single element is logically valid.
  """
  @spec get_one_id(nil) :: nil
  @spec get_one_id(JsonApi.Reference.t()) :: String.t()
  def get_one_id(nil), do: nil
  def get_one_id(%JsonApi.Reference{id: id}), do: id

  @doc """
  Gets the `id` of each element of the list, returning `nil` if the list is `nil`.
  """
  @spec get_many_ids(nil) :: nil
  @spec get_many_ids([JsonApi.Reference.t()]) :: [String.t()]
  def get_many_ids(nil), do: nil
  def get_many_ids(objects), do: Enum.map(objects, & &1.id)

  @doc """
  Validates that the module being compiled has struct keys that match its `c:fields/0` and `c:includes/0` implementations.
  """
  def __after_compile__(module_env, _) do
    module = module_env.module
    struct_name = Macro.inspect_atom(:literal, module)
    actual_struct_keys = module.__info__(:struct) |> Enum.map(fn %{field: field} -> field end)

    renames = Module.get_attribute(module, :jsonapi_object_renames, %{})
    apply_rename = fn name -> Map.get(renames, name, name) end

    expected_fields = module.fields() |> Enum.map(apply_rename)

    expected_includes =
      module.includes()
      |> Map.keys()
      |> Enum.map(apply_rename)
      |> Enum.map(&key_for_include_name/1)
      |> Enum.sort()

    expected_virtual_fields =
      if Module.defines?(module, {:virtual_fields, 0}) do
        module.virtual_fields() |> Enum.map(apply_rename)
      else
        []
      end

    expected_struct_keys =
      [:id] ++ expected_fields ++ expected_includes ++ expected_virtual_fields

    if expected_struct_keys == actual_struct_keys do
      :ok
    else
      raise format_struct_mismatch(struct_name, expected_struct_keys, actual_struct_keys)
    end
  end

  @doc """
  Transforms a potentially plural included object name into an ID struct key.

  Not intended for public API use, but only testable as a public method.

  ## Examples

      iex> import #{__MODULE__}, only: [key_for_include_name: 1]
      iex> key_for_include_name(:vehicle)
      :vehicle_id
      iex> key_for_include_name(:child_stops)
      :child_stop_ids
  """
  @spec key_for_include_name(atom()) :: atom()
  def key_for_include_name(name) do
    name_string = to_string(name)

    key_string =
      if String.ends_with?(name_string, "s") do
        case name do
          :facilities -> "facility_ids"
          _ -> String.replace_suffix(name_string, "s", "_ids")
        end
      else
        "#{name_string}_id"
      end

    String.to_atom(key_string)
  end

  @spec format_struct_mismatch(String.t(), [atom()], [atom()]) :: String.t()
  defp format_struct_mismatch(struct_name, expected_struct_keys, actual_struct_keys) do
    good_prefix =
      Enum.zip(expected_struct_keys, actual_struct_keys)
      |> Enum.take_while(fn {expected, actual} -> expected == actual end)
      |> length()

    good_suffix =
      Enum.zip(Enum.reverse(expected_struct_keys), Enum.reverse(actual_struct_keys))
      |> Enum.take_while(fn {expected, actual} -> expected == actual end)
      |> length()

    bad_expected =
      inspect_abbreviating(expected_struct_keys, good_prefix - 1, good_suffix - 1)

    bad_actual =
      inspect_abbreviating(actual_struct_keys, good_prefix - 1, good_suffix - 1)

    "Bad object struct #{struct_name}: struct keys [#{bad_actual}] don't match JsonApi.Object `fields() ++ includes()` [#{bad_expected}]"
  end

  @spec inspect_abbreviating([atom()], integer(), integer()) :: String.t()
  defp inspect_abbreviating(list, remove_start, remove_end) do
    list = Enum.map(list, &inspect/1)

    list =
      if remove_start > 0 do
        ["..."] ++ Enum.drop(list, remove_start)
      else
        list
      end

    list =
      if remove_end > 0 do
        Enum.drop(list, -remove_end) ++ ["..."]
      else
        list
      end

    Enum.join(list, ", ")
  end
end

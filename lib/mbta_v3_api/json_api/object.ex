defmodule MBTAV3API.JsonApi.Object do
  @moduledoc """
  Shared logic for all objects that can be represented as JSON:API resources.
  """
  alias MBTAV3API.JsonApi

  @doc """
  List of fields to include by default in JSON:API calls. Should match the `defstruct/1` names and orders.
  """
  @callback fields :: [atom()]
  @doc """
  Map of related objects that can be included to their types. `%{trip: :trip, stops: :stop, parent_station: :stop}`, etc. Names should match `defstruct/1`.
  """
  @callback includes :: %{atom() => atom()}
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
  @optional_callbacks serialize_filter_value: 2

  @doc """
  Sets up the `JsonApi.Object` behaviour with compile-time validation of `c:fields/0` and `c:includes/0` against the `defstruct/1`.

  Expects the `defstruct` to be `[:id, ...field names..., ...related object names...]`.
  Field names should match the order in `c:fields/1` (which should probably be alphabetized) and related object names should be alphabetized.

  By default, expects the fields and include names to match the struct keys exactly.
  If renaming a field at parse time, `use MBTAV3API.JsonApi.Object, renames: %{jsonapi_name => struct_name}`.
  """
  defmacro __using__(opts) do
    renames = Keyword.get(opts, :renames, quote(do: %{}))

    quote do
      alias MBTAV3API.JsonApi

      @behaviour JsonApi.Object

      Module.put_attribute(__MODULE__, :jsonapi_object_renames, unquote(renames))

      @after_compile JsonApi.Object
    end
  end

  @doc """
  Retrieves the module for the given JSON:API type.
  """
  @spec module_for(atom() | String.t()) :: module()
  def module_for(type)

  modules =
    for type <- [:alert, :prediction, :route, :route_pattern, :stop, :trip] do
      module = Module.concat(MBTAV3API, Macro.camelize(to_string(type)))

      def module_for(unquote(type)), do: unquote(module)
      def module_for(unquote("#{type}")), do: unquote(module)

      module
    end

  module_types = Enum.map(modules, fn module -> quote(do: unquote(module).t()) end)

  @type t :: unquote(Util.type_union(module_types))

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
    modules
    |> Enum.map_join(
      "\n",
      &"    iex> MBTAV3API.JsonApi.Object.is_json_object(%#{Macro.to_string(&1)}{})\n    true"
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

  Preserving references is useful when an object may or may not be included.
  """
  @spec parse(JsonApi.Item.t()) :: t()
  @spec parse(JsonApi.Reference.t()) :: JsonApi.Reference.t()
  def parse(%JsonApi.Item{type: type} = item), do: module_for(type).parse(item)
  def parse(%JsonApi.Reference{} = ref), do: ref

  @doc """
  Calls `parse/1` on the single element of the list, returning `nil` if the list is empty or `nil` or throwing if the list has multiple elements.

  Useful for parsing relationships where only a single element is logically valid.
  """
  @spec parse_one_related(nil | []) :: nil
  @spec parse_one_related(nonempty_list(JsonApi.Item.t())) :: t()
  @spec parse_one_related(nonempty_list(JsonApi.Reference.t())) :: JsonApi.Reference.t()
  def parse_one_related(nil), do: nil
  def parse_one_related([]), do: nil
  def parse_one_related([object]), do: parse(object)
  def parse_one_related([_ | _]), do: raise("Unexpected multiple related objects")

  @doc """
  Calls `parse/1` on each element of the list, returning `nil` if the list is `nil`.
  """
  @spec parse_many_related(nil) :: nil
  @spec parse_many_related([JsonApi.Item.t()]) :: [t()]
  @spec parse_many_related([JsonApi.Reference.t()]) :: [JsonApi.Reference.t()]
  def parse_many_related(nil), do: nil
  def parse_many_related(objects), do: Enum.map(objects, &parse/1)

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
    expected_includes = module.includes() |> Map.keys() |> Enum.map(apply_rename) |> Enum.sort()
    expected_struct_keys = [:id] ++ expected_fields ++ expected_includes

    if expected_struct_keys == actual_struct_keys do
      :ok
    else
      raise format_struct_mismatch(struct_name, expected_struct_keys, actual_struct_keys)
    end
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

    "Bad object struct #{struct_name}: struct keys [#{bad_actual}] don't match JsonApi.Object callback values [#{bad_expected}]"
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

defmodule MBTAV3API.JsonApi.Object do
  alias MBTAV3API.JsonApi

  @callback fields :: [atom()]
  @callback includes :: %{atom() => atom()}
  @callback serialize_filter_value(atom(), JsonApi.FilterValue.t()) :: JsonApi.FilterValue.t()
  @optional_callbacks serialize_filter_value: 2

  @spec module_for(atom() | String.t()) :: module()
  def module_for(type)

  modules =
    for type <- [:prediction, :route, :route_pattern, :stop, :trip] do
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

  @spec parse(JsonApi.Item.t()) :: t()
  @spec parse(JsonApi.Reference.t()) :: JsonApi.Reference.t()
  def parse(%JsonApi.Item{type: type} = item), do: module_for(type).parse(item)
  def parse(%JsonApi.Reference{} = ref), do: ref

  @spec parse_one_related(nil | []) :: nil
  @spec parse_one_related(nonempty_list(JsonApi.Item.t())) :: t()
  @spec parse_one_related(nonempty_list(JsonApi.Reference.t())) :: JsonApi.Reference.t()
  def parse_one_related(nil), do: nil
  def parse_one_related([]), do: nil
  def parse_one_related([object]), do: parse(object)
  def parse_one_related([_ | _]), do: raise("Unexpected multiple related objects")

  @spec parse_many_related(nil) :: nil
  @spec parse_many_related([JsonApi.Item.t()]) :: [t()]
  @spec parse_many_related([JsonApi.Reference.t()]) :: [JsonApi.Reference.t()]
  def parse_many_related(nil), do: nil
  def parse_many_related(objects), do: Enum.map(objects, &parse/1)
end

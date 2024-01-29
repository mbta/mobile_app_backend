defmodule MBTAV3API.JsonApi.Object do
  alias MBTAV3API.JsonApi

  @type t :: struct()

  @callback fields :: [atom()]
  @callback includes :: %{atom() => atom()}

  @spec module_for(atom() | String.t()) :: module()
  def module_for(type)

  for type <- [:prediction, :route, :route_pattern, :stop, :trip] do
    module = :"#{MBTAV3API}.#{Macro.camelize(to_string(type))}"

    def module_for(unquote(type)), do: unquote(module)
    def module_for(unquote("#{type}")), do: unquote(module)
  end

  @spec parse(JsonApi.Item.t()) :: t()
  @spec parse(JsonApi.Reference.t()) :: JsonApi.Reference.t()
  def parse(%JsonApi.Item{type: type} = item), do: module_for(type).parse(item)
  def parse(%JsonApi.Reference{} = ref), do: ref
end

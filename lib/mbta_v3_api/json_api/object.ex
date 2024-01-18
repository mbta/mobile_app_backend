defmodule MBTAV3API.JsonApi.Object do
  @callback fields :: [atom()]
  @callback includes :: %{atom() => atom()}

  def module_for(type)
  def module_for(:route), do: MBTAV3API.Route
  def module_for(:route_pattern), do: MBTAV3API.RoutePattern
  def module_for(:stop), do: MBTAV3API.Stop

  def put_fields(params, root) do
    Keyword.merge(fields(root, Keyword.get(params, :include, [])), params)
  end

  defp fields(root, includes) do
    included_types(root, includes)
    |> Enum.uniq()
    |> Enum.map(&{:"fields[#{&1}]", module_for(&1).fields() |> Enum.join(",")})
  end

  defp included_types(root, include) when is_atom(include) do
    [root, Map.fetch!(module_for(root).includes(), include)]
  end

  defp included_types(root, {include, sub_include}) do
    [included] = included_types(root, include)
    [root, included] ++ included_types(included, sub_include)
  end

  defp included_types(root, includes) when is_list(includes) do
    Enum.flat_map(includes, &included_types(root, &1))
  end
end

defmodule MBTAV3API.JsonApi.Object do
  @callback fields :: [atom()]
  @callback includes :: %{atom() => atom()}

  def module_for(type)
  def module_for(:route), do: MBTAV3API.Route
  def module_for(:route_pattern), do: MBTAV3API.RoutePattern
  def module_for(:stop), do: MBTAV3API.Stop
  def module_for(:trip), do: MBTAV3API.Trip

  def put_fields(params, root) do
    {include, params} = Keyword.pop(params, :include, [])
    params = Keyword.merge(fields(root, include), params)

    case include do
      [] ->
        params

      _ ->
        Keyword.put(
          params,
          :include,
          flat_include(include) |> Enum.map_join(",", &Enum.join(&1, "."))
        )
    end
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
    [^root, included] = included_types(root, include)
    [root, included] ++ included_types(included, sub_include)
  end

  defp included_types(root, includes) when is_list(includes) do
    Enum.flat_map(includes, &included_types(root, &1))
  end

  @spec flat_include(atom() | list(atom() | {atom(), term()})) :: Enumerable.t(list(atom()))
  defp flat_include(include) when is_atom(include) do
    [[include]]
  end

  defp flat_include({include, sub_include}) do
    Stream.concat([[include]], flat_include(sub_include) |> Stream.map(&[include | &1]))
  end

  defp flat_include(includes) when is_list(includes) do
    Stream.flat_map(includes, &flat_include/1)
  end
end

defmodule MBTAV3API.JsonApi.Params do
  alias MBTAV3API.JsonApi.FilterValue
  alias MBTAV3API.JsonApi.Object

  @type sort_param :: {atom(), :asc | :desc}
  @type fields_param :: {atom(), list(atom())}
  @type include_param :: atom() | {atom(), include_param()} | list(include_param())
  @type filter_param :: {atom(), FilterValue.t()}
  @type param ::
          {:sort, sort_param()}
          | {:fields, [fields_param()]}
          | {:include, include_param()}
          | {:filter, [filter_param()]}
  @type t :: [param()]

  @doc """
  Turns a legible parameter list into a flat HTTP-ready parameter list.

  ## Examples

      iex> MBTAV3API.JsonApi.Params.flatten_params(
      ...>   [
      ...>     sort: {:name, :asc},
      ...>     fields: [route: [:color, :short_name]],
      ...>     include: :route,
      ...>     filter: [route: ["Green-B", "Red"], canonical: true]
      ...>   ],
      ...>   :route_pattern
      ...> )
      %{
        "sort" => "name",
        "fields[route]" => "color,short_name",
        "fields[route_pattern]" => "direction_id,name,sort_order",
        "include" => "route",
        "filter[route]" => "Green-B,Red",
        "filter[canonical]" => "true"
      }

  """
  @spec flatten_params(t(), atom()) :: %{String.t() => String.t()}
  def flatten_params(params, root_type) do
    Map.merge(
      Map.merge(
        sort(params[:sort]),
        fields(root_type, params[:include], Keyword.get(params, :fields, []))
      ),
      Map.merge(include(params[:include]), filter(params[:filter]))
    )
  end

  @spec sort(nil | sort_param()) :: %{String.t() => String.t()}
  defp sort(nil), do: %{}

  defp sort({field, dir}) do
    %{
      "sort" =>
        case dir do
          :asc -> ""
          :desc -> "-"
        end <> "#{field}"
    }
  end

  @spec fields(atom(), nil | include_param(), [fields_param()]) :: %{String.t() => String.t()}
  defp fields(root_type, include, overrides) do
    included_types(root_type, include)
    |> Enum.uniq()
    |> Enum.map(&{&1, Object.module_for(&1).fields()})
    |> Keyword.merge(overrides)
    |> Map.new(fn {type, fields} -> {"fields[#{type}]", Enum.join(fields, ",")} end)
  end

  defp included_types(root_type, nil), do: [root_type]

  defp included_types(root_type, include) when is_atom(include) do
    [root_type, Map.fetch!(Object.module_for(root_type).includes(), include)]
  end

  defp included_types(root_type, {include, sub_include}) do
    [^root_type, included] = included_types(root_type, include)
    [root_type, included] ++ included_types(included, sub_include)
  end

  defp included_types(root_type, includes) when is_list(includes) do
    Enum.flat_map(includes, &included_types(root_type, &1))
  end

  @spec include(nil | include_param()) :: %{String.t() => String.t()}
  defp include(nil), do: %{}

  defp include(include) do
    %{"include" => flat_include(include) |> Enum.map_join(",", &Enum.join(&1, "."))}
  end

  @spec flat_include(nil | include_param()) :: Enumerable.t(list(atom()))
  defp flat_include(include) when is_atom(include) do
    [[include]]
  end

  defp flat_include({include, sub_include}) do
    Stream.concat([[include]], flat_include(sub_include) |> Stream.map(&[include | &1]))
  end

  defp flat_include(includes) when is_list(includes) do
    Stream.flat_map(includes, &flat_include/1)
  end

  @spec filter(nil | [filter_param()]) :: %{String.t() => String.t()}
  defp filter(nil), do: %{}

  defp filter(filters) do
    Map.new(filters, fn {field, value} ->
      {"filter[#{field}]", FilterValue.filter_value_string(value)}
    end)
  end
end

defmodule MBTAV3API.JsonApi.Params do
  alias MBTAV3API.JsonApi.FilterValue

  @type page_param :: {:offset | :limit, non_neg_integer()}
  @type sort_param :: {atom(), :asc | :desc}
  @type fields_param :: {atom(), list(atom())}
  @type include_param :: atom() | {atom(), include_param()} | list(include_param())
  @type filter_param :: {atom(), FilterValue.t()}
  @type param ::
          {:page, page_param()}
          | {:sort, sort_param()}
          | {:fields, [fields_param()]}
          | {:include, include_param()}
          | {:filter, [filter_param()]}
  @type t :: [param()]

  @doc """
  Turns a legible parameter list into a flat HTTP-ready parameter list.

  ## Examples

      iex> MBTAV3API.JsonApi.Params.flatten_params(
      ...>   [
      ...>     page: [offset: 3, limit: 2],
      ...>     sort: {:name, :asc},
      ...>     fields: [route: [:color, :short_name]],
      ...>     include: :route,
      ...>     filter: [route: ["Green-B", "Red"], canonical: true]
      ...>   ],
      ...>   MBTAV3API.RoutePattern
      ...> )
      %{
        "page[offset]" => "3",
        "page[limit]" => "2",
        "sort" => "name",
        "fields[route]" => "color,short_name",
        "fields[route_pattern]" => "canonical,direction_id,name,sort_order,typicality",
        "include" => "route",
        "filter[route]" => "Green-B,Red",
        "filter[canonical]" => "true"
      }

  """
  @spec flatten_params(t(), module()) :: %{String.t() => String.t()}
  def flatten_params(params, root_module) do
    [
      page(params[:page]),
      sort(params[:sort]),
      fields(root_module, params[:include], Keyword.get(params, :fields, [])),
      include(params[:include]),
      filter(root_module, params[:filter])
    ]
    |> Enum.reduce(&Map.merge/2)
  end

  @spec page(nil | [page_param()]) :: %{String.t() => String.t()}
  defp page(nil), do: %{}
  defp page(args), do: Map.new(args, fn {k, v} -> {"page[#{k}]", to_string(v)} end)

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

  @spec fields(module(), nil | include_param(), [fields_param()]) :: %{String.t() => String.t()}
  defp fields(root_module, include, overrides) do
    included_modules(root_module, include)
    |> Enum.uniq()
    |> Enum.map(&{&1.jsonapi_type(), &1.fields()})
    |> Keyword.merge(overrides)
    |> Map.new(fn {type, fields} -> {"fields[#{type}]", Enum.join(fields, ",")} end)
  end

  defp included_modules(root_module, nil), do: [root_module]

  defp included_modules(root_module, include) when is_atom(include) do
    [root_module, Map.fetch!(root_module.includes(), include)]
  end

  defp included_modules(root_module, {include, sub_include}) do
    [^root_module, included] = included_modules(root_module, include)
    [root_module, included] ++ included_modules(included, sub_include)
  end

  defp included_modules(root_module, includes) when is_list(includes) do
    Enum.flat_map(includes, &included_modules(root_module, &1))
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

  @spec filter(atom(), nil | [filter_param()]) :: %{String.t() => String.t()}
  defp filter(_, nil), do: %{}

  defp filter(module, filters) do
    has_serialize? = function_exported?(module, :serialize_filter_value, 2)

    Map.new(filters, fn {field, value} ->
      {"filter[#{field}]",
       FilterValue.filter_value_string(
         value,
         if has_serialize? do
           &module.serialize_filter_value(field, &1)
         end
       )}
    end)
  end
end

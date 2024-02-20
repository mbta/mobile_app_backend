defmodule MBTAV3API.RoutePattern do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          direction_id: 0 | 1,
          name: String.t(),
          sort_order: integer(),
          typicality: typicality(),
          representative_trip: MBTAV3API.Trip.t() | JsonApi.Reference.t() | nil,
          route: MBTAV3API.Route.t() | JsonApi.Reference.t() | nil
        }

  Util.declare_enum(
    :typicality,
    Util.enum_values(:index, [nil, :typical, :deviation, :atypical, :diversion, :canonical])
  )

  @derive Jason.Encoder
  defstruct [:id, :direction_id, :name, :sort_order, :typicality, :representative_trip, :route]

  @impl JsonApi.Object
  def fields, do: [:direction_id, :name, :sort_order, :typicality]

  @impl JsonApi.Object
  def includes, do: %{representative_trip: :trip, route: :route}

  @spec get_all(JsonApi.Params.t(), Keyword.t()) :: {:ok, [t()]} | {:error, term()}
  def get_all(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :route_pattern)

    case MBTAV3API.get_json("/route_patterns", params, opts) do
      %JsonApi{data: data} -> {:ok, Enum.map(data, &parse/1)}
      {:error, error} -> {:error, error}
    end
  end

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      direction_id: item.attributes["direction_id"],
      name: item.attributes["name"],
      sort_order: item.attributes["sort_order"],
      typicality: parse_typicality(item.attributes["typicality"]),
      representative_trip:
        JsonApi.Object.parse_one_related(item.relationships["representative_trip"]),
      route: JsonApi.Object.parse_one_related(item.relationships["route"])
    }
  end

  @spec get_pattern_ids_by_stop([t()], MapSet.t(String.t()) | nil) ::
          %{String.t() => [String.t()]}
  def get_pattern_ids_by_stop(route_patterns, filter_stop_ids \\ nil) do
    route_patterns
    |> Enum.flat_map(fn
      %__MODULE__{
        id: route_pattern_id,
        representative_trip: %MBTAV3API.Trip{stops: trip_stops}
      } ->
        trip_stops
        |> Enum.filter(&(filter_stop_ids == nil || MapSet.member?(filter_stop_ids, &1.id)))
        |> Enum.map(&%{stop_id: &1.id, route_pattern_id: route_pattern_id})
    end)
    |> Enum.group_by(& &1.stop_id, & &1.route_pattern_id)
  end

  @spec get_route_map([t()]) :: %{String.t() => MBTAV3API.Route.t()}
  def get_route_map(route_patterns) do
    route_patterns
    |> Enum.map(& &1.route)
    |> Map.new(&{&1.id, &1})
  end
end

defmodule MBTAV3API.RoutePattern do
  alias MBTAV3API.JsonApi

  @behaviour JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          direction_id: 0 | 1,
          name: String.t(),
          sort_order: integer(),
          representative_trip: MBTAV3API.Trip.t() | JsonApi.Reference.t() | nil,
          route: MBTAV3API.Route.t() | JsonApi.Reference.t() | nil
        }

  @derive Jason.Encoder
  defstruct [:id, :direction_id, :name, :sort_order, :representative_trip, :route]

  @impl JsonApi.Object
  def fields, do: [:direction_id, :name, :sort_order]

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
      representative_trip:
        JsonApi.Object.parse_one_related(item.relationships["representative_trip"]),
      route: JsonApi.Object.parse_one_related(item.relationships["route"])
    }
  end
end

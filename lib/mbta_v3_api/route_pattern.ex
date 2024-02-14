defmodule MBTAV3API.RoutePattern do
  use MBTAV3API.JsonApi.Object

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
  @spec fields() :: [:direction_id | :name | :sort_order, ...]
  def fields, do: [:direction_id, :name, :sort_order]

  @impl JsonApi.Object
  def includes, do: %{representative_trip: :trip, route: :route}

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

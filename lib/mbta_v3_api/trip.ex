defmodule MBTAV3API.Trip do
  use MBTAV3API.JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          headsign: String.t(),
          route_pattern: MBTAV3API.RoutePattern.t() | JsonApi.Reference.t() | nil,
          shape: MBTAV3API.Shape.t() | JsonApi.Reference.t() | nil,
          stops: [MBTAV3API.Stop.t() | JsonApi.Reference.t()] | nil
        }

  @derive Jason.Encoder
  defstruct [:id, :headsign, :route_pattern, :shape, :stops]

  def fields, do: [:headsign]

  def includes,
    do: %{route_pattern: MBTAV3API.RoutePattern, shape: MBTAV3API.Shape, stops: MBTAV3API.Stop}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      headsign: item.attributes["headsign"],
      route_pattern: JsonApi.Object.parse_one_related(item.relationships["route_pattern"]),
      shape: JsonApi.Object.parse_one_related(item.relationships["shape"]),
      stops: JsonApi.Object.parse_many_related(item.relationships["stops"])
    }
  end
end

defmodule MBTAV3API.Trip do
  use MBTAV3API.JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          direction_id: 0 | 1,
          headsign: String.t(),
          route_id: String.t(),
          route_pattern_id: String.t(),
          shape_id: String.t(),
          stop_ids: [String.t()] | nil
        }

  @derive Jason.Encoder
  defstruct [:id, :direction_id, :headsign, :route_id, :route_pattern_id, :shape_id, :stop_ids]

  def fields, do: [:direction_id, :headsign]

  def includes do
    %{
      route: MBTAV3API.Route,
      route_pattern: MBTAV3API.RoutePattern,
      shape: MBTAV3API.Shape,
      stops: MBTAV3API.Stop
    }
  end

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      direction_id: item.attributes["direction_id"],
      headsign: item.attributes["headsign"],
      route_id: JsonApi.Object.get_one_id(item.relationships["route"]),
      route_pattern_id: JsonApi.Object.get_one_id(item.relationships["route_pattern"]),
      shape_id: JsonApi.Object.get_one_id(item.relationships["shape"]),
      stop_ids: JsonApi.Object.get_many_ids(item.relationships["stops"])
    }
  end
end

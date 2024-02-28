defmodule MBTAV3API.Trip do
  use MBTAV3API.JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          headsign: String.t(),
          route_pattern_id: String.t(),
          stop_ids: [String.t()] | nil
        }

  @derive Jason.Encoder
  defstruct [:id, :headsign, :route_pattern_id, :stop_ids]

  def fields, do: [:headsign]

  def includes, do: %{route_pattern: MBTAV3API.RoutePattern, stops: MBTAV3API.Stop}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      headsign: item.attributes["headsign"],
      route_pattern_id: JsonApi.Object.get_one_id(item.relationships["route_pattern"]),
      stop_ids: JsonApi.Object.get_many_ids(item.relationships["stops"])
    }
  end
end

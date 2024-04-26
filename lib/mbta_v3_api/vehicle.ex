defmodule MBTAV3API.Vehicle do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          bearing: number(),
          current_status: current_status(),
          direction_id: 0 | 1,
          latitude: float(),
          longitude: float(),
          route_id: String.t() | nil,
          stop_id: String.t() | nil,
          trip_id: String.t() | nil
        }
  Util.declare_enum(
    :current_status,
    Util.enum_values(:uppercase_string, [:incoming_at, :stopped_at, :in_transit_to])
  )

  @derive Jason.Encoder
  defstruct [
    :id,
    :bearing,
    :current_status,
    :direction_id,
    :latitude,
    :longitude,
    :route_id,
    :stop_id,
    :trip_id
  ]

  @impl JsonApi.Object
  def fields, do: [:bearing, :current_status, :direction_id, :latitude, :longitude]

  @impl JsonApi.Object
  def includes, do: %{route: MBTAV3API.Route, stop: MBTAV3API.Stop, trip: MBTAV3API.Trip}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      bearing: item.attributes["bearing"],
      current_status: parse_current_status(item.attributes["current_status"]),
      direction_id: item.attributes["direction_id"],
      latitude: item.attributes["latitude"],
      longitude: item.attributes["longitude"],
      route_id: JsonApi.Object.get_one_id(item.relationships["route"]),
      stop_id: JsonApi.Object.get_one_id(item.relationships["stop"]),
      trip_id: JsonApi.Object.get_one_id(item.relationships["trip"])
    }
  end
end

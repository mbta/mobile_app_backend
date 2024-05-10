defmodule MBTAV3API.Vehicle do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          bearing: number() | nil,
          current_status: current_status(),
          direction_id: 0 | 1,
          latitude: float(),
          longitude: float(),
          occupancy_status: occupancy_status(),
          updated_at: DateTime.t(),
          route_id: String.t() | nil,
          stop_id: String.t() | nil,
          trip_id: String.t() | nil
        }
  Util.declare_enum(
    :current_status,
    Util.enum_values(:uppercase_string, [:incoming_at, :stopped_at, :in_transit_to])
  )

  Util.declare_enum(
    :occupancy_status,
    Util.enum_values(:uppercase_string, [
      :many_seats_available,
      :few_seats_available,
      :standing_room_only,
      :crushed_standing_room_only,
      :full,
      :not_accepting_passengers,
      :no_data_available
    ])
  )

  @derive Jason.Encoder
  defstruct [
    :id,
    :bearing,
    :current_status,
    :direction_id,
    :latitude,
    :longitude,
    :occupancy_status,
    :updated_at,
    :route_id,
    :stop_id,
    :trip_id
  ]

  @impl JsonApi.Object
  def fields,
    do: [
      :bearing,
      :current_status,
      :direction_id,
      :latitude,
      :longitude,
      :occupancy_status,
      :updated_at
    ]

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
      occupancy_status: parse_occupancy_status(item.attributes["occupancy_status"]),
      updated_at: Util.parse_datetime!(item.attributes["updated_at"]),
      route_id: JsonApi.Object.get_one_id(item.relationships["route"]),
      stop_id: JsonApi.Object.get_one_id(item.relationships["stop"]),
      trip_id: JsonApi.Object.get_one_id(item.relationships["trip"])
    }
  end
end

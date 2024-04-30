defmodule MBTAV3API.Schedule do
  use MBTAV3API.JsonApi.Object, renames: %{pickup_type: :pick_up_type}
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          arrival_time: DateTime.t() | nil,
          departure_time: DateTime.t() | nil,
          drop_off_type: stop_edge_type(),
          pick_up_type: stop_edge_type(),
          stop_sequence: integer(),
          route_id: String.t(),
          stop_id: String.t() | nil,
          trip_id: String.t() | nil
        }

  Util.declare_enum(
    :stop_edge_type,
    Util.enum_values(:index, [:regular, :unavailable, :call_agency, :coordinate_with_driver])
  )

  @derive Jason.Encoder
  defstruct [
    :id,
    :arrival_time,
    :departure_time,
    :drop_off_type,
    :pick_up_type,
    :stop_sequence,
    :route_id,
    :stop_id,
    :trip_id
  ]

  @impl JsonApi.Object
  def fields, do: [:arrival_time, :departure_time, :drop_off_type, :pickup_type, :stop_sequence]

  @impl JsonApi.Object
  def includes, do: %{route: MBTAV3API.Route, stop: MBTAV3API.Stop, trip: MBTAV3API.Trip}

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      arrival_time: Util.parse_optional_datetime!(item.attributes["arrival_time"]),
      departure_time: Util.parse_optional_datetime!(item.attributes["departure_time"]),
      drop_off_type: parse_stop_edge_type(item.attributes["drop_off_type"]),
      pick_up_type: parse_stop_edge_type(item.attributes["pickup_type"]),
      stop_sequence: item.attributes["stop_sequence"],
      route_id: JsonApi.Object.get_one_id(item.relationships["route"]),
      stop_id: JsonApi.Object.get_one_id(item.relationships["stop"]),
      trip_id: JsonApi.Object.get_one_id(item.relationships["trip"])
    }
  end
end

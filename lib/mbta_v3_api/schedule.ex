defmodule MBTAV3API.Schedule do
  use MBTAV3API.JsonApi.Object, renames: %{pickup_type: :pick_up_type}
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          arrival_time: DateTime.t() | nil,
          departure_time: DateTime.t() | nil,
          drop_off_type: stop_edge_type(),
          pick_up_type: stop_edge_type(),
          stop_headsign: String.t() | nil,
          stop_sequence: integer(),
          added_route_ids: [String.t()] | nil,
          route_id: String.t(),
          stop_id: String.t() | nil,
          trip_id: String.t() | nil
        }

  Util.declare_enum(
    :stop_edge_type,
    Util.enum_values(:index, [:regular, :unavailable, :call_agency, :coordinate_with_driver]),
    Util.FailOnUnknown
  )

  @derive Jason.Encoder
  defstruct [
    :id,
    :arrival_time,
    :departure_time,
    :drop_off_type,
    :pick_up_type,
    :stop_headsign,
    :stop_sequence,
    :added_route_ids,
    :route_id,
    :stop_id,
    :trip_id
  ]

  @impl JsonApi.Object
  def fields,
    do: [
      :arrival_time,
      :departure_time,
      :drop_off_type,
      :pickup_type,
      :stop_headsign,
      :stop_sequence
    ]

  @impl JsonApi.Object
  def includes do
    %{
      added_routes: MBTAV3API.Route,
      route: MBTAV3API.Route,
      stop: MBTAV3API.Stop,
      trip: MBTAV3API.Trip
    }
  end

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      arrival_time: Util.parse_optional_datetime!(item.attributes["arrival_time"]),
      departure_time: Util.parse_optional_datetime!(item.attributes["departure_time"]),
      drop_off_type: parse_stop_edge_type!(item.attributes["drop_off_type"]),
      pick_up_type: parse_stop_edge_type!(item.attributes["pickup_type"]),
      stop_headsign: item.attributes["stop_headsign"],
      stop_sequence: item.attributes["stop_sequence"],
      added_route_ids: JsonApi.Object.get_many_ids(item.relationships["added_routes"]),
      route_id: JsonApi.Object.get_one_id(item.relationships["route"]),
      stop_id: JsonApi.Object.get_one_id(item.relationships["stop"]),
      trip_id: JsonApi.Object.get_one_id(item.relationships["trip"])
    }
  end

  @spec expand_added_routes(t()) :: [t()]
  def expand_added_routes(%__MODULE__{} = schedule) do
    [schedule] ++
      for added_route_id <- schedule.added_route_ids || [] do
        %__MODULE__{
          schedule
          | id: "#{schedule.id}+r#{added_route_id}",
            route_id: added_route_id,
            added_route_ids: []
        }
      end
  end
end

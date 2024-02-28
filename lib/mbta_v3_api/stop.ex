defmodule MBTAV3API.Stop do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          latitude: float(),
          longitude: float(),
          name: String.t(),
          location_type: location_type(),
          child_stop_ids: [String.t()] | nil,
          parent_station_id: String.t() | nil
        }

  Util.declare_enum(
    :location_type,
    Util.enum_values(:index, [:stop, :station, :entrance_exit, :generic_node, :boarding_area])
  )

  defstruct [
    :id,
    :latitude,
    :longitude,
    :name,
    :location_type,
    :child_stop_ids,
    :parent_station_id
  ]

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> Map.from_struct()
      |> Map.reject(fn {_k, v} -> is_nil(v) end)
      |> Jason.Encode.map(opts)
    end
  end

  def parent_id(%__MODULE__{parent_station_id: nil} = stop), do: stop.id
  def parent_id(%__MODULE__{parent_station_id: parent_id}), do: parent_id

  @impl JsonApi.Object
  def fields, do: [:latitude, :longitude, :name, :location_type]

  @impl JsonApi.Object
  def includes,
    do: %{
      child_stops: __MODULE__,
      parent_station: __MODULE__
    }

  @impl JsonApi.Object
  def serialize_filter_value(:route_type, route_type) do
    MBTAV3API.Route.serialize_type(route_type)
  end

  def serialize_filter_value(:location_type, location_type) do
    serialize_location_type(location_type)
  end

  def serialize_filter_value(_field, value), do: value

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      latitude: item.attributes["latitude"],
      longitude: item.attributes["longitude"],
      name: item.attributes["name"],
      location_type:
        if location_type = item.attributes["location_type"] do
          parse_location_type(location_type)
        end,
      parent_station_id: JsonApi.Object.get_one_id(item.relationships["parent_station"]),
      child_stop_ids: JsonApi.Object.get_many_ids(item.relationships["child_stops"])
    }
  end
end

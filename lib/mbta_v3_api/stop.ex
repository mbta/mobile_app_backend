defmodule MBTAV3API.Stop do
  alias MBTAV3API.JsonApi.Object
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          latitude: float(),
          longitude: float(),
          name: String.t(),
          location_type: location_type(),
          vehicle_type: MBTAV3API.Route.type() | nil,
          description: String.t() | nil,
          platform_name: String.t() | nil,
          child_stop_ids: [String.t()] | nil,
          connecting_stop_ids: [String.t()] | nil,
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
    :vehicle_type,
    :description,
    :platform_name,
    :child_stop_ids,
    :connecting_stop_ids,
    :parent_station_id
  ]

  @impl JsonApi.Object
  def fields do
    [
      :latitude,
      :longitude,
      :name,
      :location_type,
      :vehicle_type,
      :description,
      :platform_name
    ]
  end

  @impl JsonApi.Object
  def includes do
    %{
      child_stops: __MODULE__,
      connecting_stops: __MODULE__,
      parent_station: __MODULE__
    }
  end

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

  @spec parent_if_exists(t(), %{id() => t()}) :: t()
  @doc """
  If the stop has a parent station and that parent is present in the map of stops, return the parent.
  Otherwise, returns the stop as-is.
  """
  def parent_if_exists(%__MODULE__{parent_station_id: nil} = child_stop, _stops_by_id) do
    child_stop
  end

  def parent_if_exists(
        %__MODULE__{parent_station_id: parent_station_id} = child_stop,
        stops_by_id
      ) do
    Map.get(stops_by_id, parent_station_id, child_stop)
  end

  def parent_if_exists(stop, _stops_by_id) do
    stop
  end

  @spec stop_id_to_children(Object.stop_map(), [id()]) :: %{id() => [id()]}
  @doc """
  Build a map containing the given stop_ids to their corresponding child stop ids.
  Excludes child stops that don't have `location_type: :stop`
  """
  def stop_id_to_children(all_stops_by_id, target_stop_ids) do
    Map.take(all_stops_by_id, target_stop_ids)
    |> Map.new(fn {stop_id, stop} ->
      {stop_id,
       Enum.filter(
         List.wrap(stop.child_stop_ids),
         fn child_stop_id ->
           case Map.get(all_stops_by_id, child_stop_id) do
             nil -> false
             %{location_type: location_type} -> location_type == :stop
           end
         end
       )}
    end)
  end

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
      vehicle_type:
        if vehicle_type = item.attributes["vehicle_type"] do
          MBTAV3API.Route.parse_type(vehicle_type)
        end,
      description: item.attributes["description"],
      platform_name: item.attributes["platform_name"],
      child_stop_ids: JsonApi.Object.get_many_ids(item.relationships["child_stops"]),
      connecting_stop_ids: JsonApi.Object.get_many_ids(item.relationships["connecting_stops"]),
      parent_station_id: JsonApi.Object.get_one_id(item.relationships["parent_station"])
    }
  end

  @spec include_missing_siblings(JsonApi.Object.stop_map(), JsonApi.Object.stop_map()) ::
          JsonApi.Object.stop_map()
  def include_missing_siblings(stops, extra_stops) do
    parents =
      stops
      |> Map.values()
      |> Enum.filter(&(&1.parent_station_id != nil))
      |> Enum.map(&Map.fetch!(extra_stops, &1.parent_station_id))

    missing_sibling_stops =
      parents
      |> Enum.flat_map(& &1.child_stop_ids)
      |> Enum.reject(&Map.has_key?(stops, &1))
      |> Enum.map(&Map.fetch!(extra_stops, &1))
      |> Enum.filter(&(&1.location_type in [:stop, :station]))
      |> Map.new(&{&1.id, &1})

    Map.merge(stops, missing_sibling_stops)
  end
end

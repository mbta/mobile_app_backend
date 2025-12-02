defmodule MBTAV3API.Alert.InformedEntity do
  require Util

  @type t :: %__MODULE__{
          activities: [activity()],
          direction_id: 0 | 1 | nil,
          facility: String.t() | nil,
          route: String.t() | nil,
          route_type: MBTAV3API.Route.type() | nil,
          stop: String.t() | nil,
          trip: String.t() | nil
        }

  Util.declare_enum(
    :activity,
    Util.enum_values(
      :uppercase_string,
      [
        :board,
        :bringing_bike,
        :exit,
        :park_car,
        :ride,
        :store_bike,
        :using_escalator,
        :using_wheelchair
      ]
    ),
    nil
  )

  @derive Jason.Encoder
  defstruct activities: [],
            direction_id: nil,
            facility: nil,
            route: nil,
            route_type: nil,
            stop: nil,
            trip: nil

  @spec parse!(map()) :: t()
  def parse!(data) when is_map(data) do
    %__MODULE__{
      activities: data["activities"] |> Enum.map(&parse_activity/1) |> Enum.reject(&is_nil/1),
      direction_id: data["direction_id"],
      facility: data["facility"],
      route: data["route"],
      route_type:
        if route_type = data["route_type"] do
          MBTAV3API.Route.parse_type!(route_type)
        end,
      stop: data["stop"],
      trip: data["trip"]
    }
  end

  @spec matches?(term(), term()) :: boolean()
  defp matches?(actual, expected) do
    is_nil(actual) or is_nil(expected) or actual == expected
  end

  @spec activity_in?(t(), [activity()]) :: boolean()
  def activity_in?(informed_entity, activities) do
    Enum.any?(activities, &(&1 in informed_entity.activities))
  end

  def direction?(informed_entity, direction) do
    matches?(informed_entity.direction_id, direction)
  end

  def route?(informed_entity, route) do
    matches?(informed_entity.route, route)
  end

  def route_in?(informed_entity, routes) do
    is_nil(informed_entity.route) or informed_entity.route in routes
  end

  def stop_in?(informed_entity, stops) do
    is_nil(informed_entity.stop) or informed_entity.stop in stops
  end

  def trip?(informed_entity, trip) do
    matches?(informed_entity.trip, trip)
  end
end

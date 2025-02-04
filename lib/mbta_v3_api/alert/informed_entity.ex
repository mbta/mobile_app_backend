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
  defstruct [:activities, :direction_id, :facility, :route, :route_type, :stop, :trip]

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
end

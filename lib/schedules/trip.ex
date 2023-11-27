defmodule Schedules.Trip do
  @moduledoc """
  Representation of GTFS trips.
  """

  alias RoutePatterns.RoutePattern
  alias Routes.Shape
  alias Vehicles.Vehicle

  @derive Jason.Encoder

  defstruct [
    :id,
    :name,
    :headsign,
    :direction_id,
    :shape_id,
    :route_pattern_id,
    :occupancy,
    bikes_allowed?: false
  ]

  @type id_t :: String.t()
  @type headsign :: String.t()
  @type t :: %__MODULE__{
          id: id_t,
          name: String.t(),
          headsign: headsign,
          direction_id: 0 | 1,
          shape_id: Shape.id_t() | nil,
          route_pattern_id: RoutePattern.id_t() | nil,
          bikes_allowed?: boolean,
          occupancy: Vehicle.crowding() | nil
        }
end

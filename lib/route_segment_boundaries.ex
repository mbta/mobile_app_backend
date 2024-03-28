defmodule MobileAppBackend.RouteSegmentBoundaries do
  @doc """
  A route segment is a conceptual chunk of a route between a set of stops.
  It is a way to break overlapping route patterns into non-overlapping segments.
  Unlike `MobileAppBackend.RouteSegment`, this stores only the first & last stop
  of the segment.
  """
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Stop

  @type t :: %__MODULE__{
          id: String.t(),
          source_route_pattern_id: RoutePattern.id(),
          route_id: Route.id(),
          first_stop: Stop.t(),
          last_stop: Stop.t()
        }

  @derive Jason.Encoder
  defstruct [:id, :source_route_pattern_id, :route_id, :first_stop, :last_stop]
end

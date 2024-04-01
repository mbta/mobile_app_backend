defmodule MobileAppBackend.MapFriendlyRouteShape do
  @doc """
  A shape for display on a map. Contains the full shape for a route pattern
  and the segments of that route pattern that can be safely rendered without overlapping
  other route shapes on the map.
  """
  alias MBTAV3API.Route
  alias MBTAV3API.RoutePattern
  alias MBTAV3API.Shape
  alias MBTAV3API.Trip
  alias MobileAppBackend.RouteSegment
  alias MobileAppBackend.RouteSegmentBoundaries

  @type t :: %__MODULE__{
          route_pattern_id: String.t(),
          route_segments: [RouteSegmentBoundaries.t()],
          color: String.t(),
          shape: Shape.t()
        }

  @derive Jason.Encoder
  defstruct [:route_pattern_id, :route_segments, :color, :shape]

  @spec from_segments(
          [RouteSegment.t()],
          %{RoutePattern.id() => RoutePattern.t()},
          %{Route.id() => Route.t()},
          %{Trip.id() => Trip.t()},
          %{Shape.id() => Shape.t()}
        ) :: [t()]
  @doc """
  Group a list of route segments by their source route pattern and include the associated
  route shape
  """
  def from_segments(all_segments, route_patterns_by_id, routes_by_id, trips_by_id, shapes_by_id) do
    all_segments
    |> Enum.group_by(&{&1.source_route_pattern_id, &1.route_id})
    |> Enum.map(fn {{route_pattern_id, route_id}, route_segments} ->
      trip_id = Map.fetch!(route_patterns_by_id, route_pattern_id).representative_trip_id
      shape_id = Map.fetch!(trips_by_id, trip_id).shape_id
      shape = Map.fetch!(shapes_by_id, shape_id)

      %__MODULE__{
        route_pattern_id: route_pattern_id,
        route_segments:
          Enum.map(
            route_segments,
            &%RouteSegmentBoundaries{
              id: &1.id,
              source_route_pattern_id: &1.source_route_pattern_id,
              route_id: &1.route_id,
              first_stop: List.first(&1.stops),
              last_stop: List.last(&1.stops)
            }
          ),
        color: Map.fetch!(routes_by_id, route_id).color,
        shape: shape
      }
    end)
  end
end

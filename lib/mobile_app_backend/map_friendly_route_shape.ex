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

  @type t :: %__MODULE__{
          source_route_pattern_id: RoutePattern.id(),
          source_route_id: Route.id(),
          route_segments: [RouteSegment.t()],
          shape: Shape.t()
        }

  @derive Jason.Encoder
  defstruct [:source_route_pattern_id, :source_route_id, :route_segments, :shape]

  @spec from_segments(
          [RouteSegment.t()],
          %{RoutePattern.id() => RoutePattern.t()},
          %{Trip.id() => Trip.t()},
          %{Shape.id() => Shape.t()}
        ) :: [t()]
  @doc """
  Group a list of route segments by their source route pattern and include the associated
  route shape. Returned in ascending route pattern sort order.
  """
  def from_segments(all_segments, route_patterns_by_id, trips_by_id, shapes_by_id) do
    all_segments
    |> Enum.group_by(&{&1.source_route_pattern_id, &1.source_route_id})
    |> Enum.sort_by(fn {{source_route_pattern_id, _route_id}, _segments} ->
      Map.fetch!(route_patterns_by_id, source_route_pattern_id).sort_order
    end)
    |> Enum.map(fn {{source_route_pattern_id, source_route_id}, route_segments} ->
      trip_id = Map.fetch!(route_patterns_by_id, source_route_pattern_id).representative_trip_id
      shape_id = Map.fetch!(trips_by_id, trip_id).shape_id
      shape = Map.fetch!(shapes_by_id, shape_id)

      %__MODULE__{
        source_route_pattern_id: source_route_pattern_id,
        source_route_id: source_route_id,
        route_segments: route_segments,
        shape: shape
      }
    end)
  end
end

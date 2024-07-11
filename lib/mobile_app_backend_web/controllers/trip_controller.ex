defmodule MobileAppBackendWeb.TripController do
  alias MBTAV3API.Repository
  use MobileAppBackendWeb, :controller

  def map(conn, %{"trip_id" => trip_id}) do
    {:ok,
     %{
       data: trips,
       included: %{shapes: shapes_by_id, route_patterns: route_patterns, trips: included_trips}
     }} =
      Repository.trips(
        filter: [id: trip_id],
        include: [:shape, :stops, [route_pattern: [representative_trip: :stops]]],
        fields: [stop: []]
      )

    if Enum.empty?(trips) do
      conn = put_status(conn, :not_found)
      json(conn, %{code: conn.status, message: "Trip not found: #{trip_id}"})
    else
      [trip] = trips

      stop_ids =
        if Enum.empty?(trip.stop_ids) do
          # Fall back to stops on the representative trip
          resolve_representative_trip_stops(trip, route_patterns, included_trips)
        else
          trip.stop_ids
        end

      json(conn, %{
        shape_with_stops: %{
          route_id: trip.route_id,
          route_pattern_id: trip.route_pattern_id,
          direction_id: trip.direction_id,
          stop_ids: stop_ids,
          shape: Map.get(shapes_by_id, trip.shape_id)
        }
      })
    end
  end

  defp resolve_representative_trip_stops(
         %{route_pattern_id: route_pattern_id} = _trip,
         route_patterns,
         included_trips
       )
       when is_map_key(route_patterns, route_pattern_id) do
    route_pattern = Map.fetch!(route_patterns, route_pattern_id)

    representative_trip = Map.get(included_trips, route_pattern.representative_trip_id)
    if is_nil(representative_trip), do: [], else: representative_trip.stop_ids
  end

  defp resolve_representative_trip_stops(_trip, _route_patterns, _included_trips) do
    []
  end
end

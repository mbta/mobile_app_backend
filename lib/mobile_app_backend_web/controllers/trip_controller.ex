defmodule MobileAppBackendWeb.TripController do
  alias MBTAV3API.Repository
  use MobileAppBackendWeb, :controller

  def map(conn, %{"trip_id" => trip_id}) do
    {:ok, %{data: trips, included: %{shapes: shapes_by_id, stops: stops_by_id}}} =
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
          # Fall back to route pattern stops for added trips
          Map.keys(stops_by_id)
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
end

defmodule MobileAppBackendWeb.TripController do
  alias MBTAV3API.Repository
  use MobileAppBackendWeb, :controller

  def map(conn, %{"trip_id" => trip_id}) do
    {:ok, %{data: trips, included: %{shapes: shapes}}} =
      Repository.trips(
        filter: [id: trip_id],
        include: [:shape, :stops],
        fields: [stop: []]
      )

    if Enum.empty?(trips) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Trip not found: #{trip_id}"})
    else
      [trip] = trips

      json(conn, %{
        route_id: trip.route_id,
        route_pattern_id: trip.route_pattern_id,
        direction_id: trip.direction_id,
        stop_ids: trip.stop_ids,
        shape: Map.get(shapes, trip.shape_id)
      })
    end
  end
end

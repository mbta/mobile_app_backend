defmodule MobileAppBackendWeb.TripController do
  alias MBTAV3API.Repository
  alias MobileAppBackendWeb.ShapesController
  use MobileAppBackendWeb, :controller

  def trip(conn, %{"trip_id" => trip_id}) do
    {:ok,
     %{
       data: trips,
       included: %{route_patterns: route_patterns, trips: included_trips}
     }} =
      Repository.trips(
        filter: [id: trip_id],
        include: [:stops, [route_pattern: [representative_trip: :stops]]],
        fields: [stop: []]
      )

    if Enum.empty?(trips) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Trip not found: #{trip_id}"})
    else
      [trip] = trips

      stop_ids = get_stop_ids(trip, route_patterns, included_trips)

      json(conn, %{
        trip: Map.put(trip, :stop_ids, stop_ids)
      })
    end
  end

  def map(conn, %{"trip_id" => trip_id}) do
    case get_trip_shape_data(trip_id) do
      {:ok, data} ->
        json(conn, get_map_shapes(data))

      {:not_found, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{message: message})
    end
  end

  def map_friendly(conn, %{"trip_id" => trip_id}) do
    case get_trip_shape_data(trip_id) do
      {:ok, data} ->
        json(conn, get_map_friendly_shapes(data))

      {:not_found, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{message: message})
    end
  end

  defp get_stop_ids(trip, route_patterns, included_trips) do
    if Enum.empty?(trip.stop_ids) do
      # Fall back to stops on the representative trip
      resolve_representative_trip_stops(trip, route_patterns, included_trips)
    else
      trip.stop_ids
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

  defp get_trip_shape_data(trip_id) do
    {:ok,
     %{
       data: trips,
       included: %{
         shapes: shapes_by_id,
         stops: stops_by_id,
         route_patterns: route_patterns,
         routes: included_routes,
         trips: included_trips
       }
     }} =
      Repository.trips(
        filter: [id: trip_id],
        include: [
          :shape,
          :stops,
          [route_pattern: [route: [], representative_trip: [:shape, :stops]]]
        ],
        fields: [stop: []]
      )

    if Enum.empty?(trips) do
      {:not_found, "Trip not found: #{trip_id}"}
    else
      [trip] = trips

      {:ok,
       %{
         trip: trip,
         shapes_by_id: shapes_by_id,
         stops_by_id: stops_by_id,
         route_patterns: route_patterns,
         included_routes: included_routes,
         included_trips: included_trips
       }}
    end
  end

  defp get_map_shapes(%{
         trip: trip,
         shapes_by_id: shapes_by_id,
         route_patterns: route_patterns,
         included_trips: included_trips
       }) do
    stop_ids = get_stop_ids(trip, route_patterns, included_trips)

    %{
      shape_with_stops: %{
        route_id: trip.route_id,
        route_pattern_id: trip.route_pattern_id,
        direction_id: trip.direction_id,
        stop_ids: stop_ids,
        shape: Map.get(shapes_by_id, trip.shape_id)
      }
    }
  end

  defp get_map_friendly_shapes(%{
         trip: trip,
         shapes_by_id: shapes_by_id,
         stops_by_id: stops_by_id,
         route_patterns: route_patterns,
         included_routes: included_routes,
         included_trips: included_trips
       }) do
    %{
      map_friendly_route_shapes:
        %{
          route_patterns: [Map.fetch!(route_patterns, trip.route_pattern_id)],
          routes_by_id: included_routes,
          trips_by_id: Map.merge(%{trip.id => trip}, included_trips),
          shapes_by_id: shapes_by_id,
          stops_by_id: stops_by_id
        }
        |> ShapesController.map_friendly_route_shapes()
    }
  end
end

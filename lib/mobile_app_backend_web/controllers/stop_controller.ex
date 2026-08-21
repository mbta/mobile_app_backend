defmodule MobileAppBackendWeb.StopController do
  require Logger
  alias MBTAV3API.Repository
  alias MobileAppBackendWeb.ShapesController
  use MobileAppBackendWeb, :controller

  def map(conn, %{"stop_id" => stop_id}) do
    shapes_data =
      stop_id
      |> fetch_shape_data_for_map()
      |> ShapesController.map_friendly_route_shapes()

    json(conn, %{
      map_friendly_route_shapes: shapes_data,
      child_stops: fetch_child_stops(stop_id)
    })
  end

  defp fetch_child_stops(stop_id) do
    {:ok, %{included: %{stops: child_stops}}} =
      Repository.stops(
        filter: [id: stop_id],
        include: [:child_stops]
      )

    # Generic nodes often don't contain coordinates, but the frontend expects
    # all stops to have coordinates, and we have no use for them, so they're removed.
    {time_in_us, result} =
      :timer.tc(fn ->
        child_stops
        |> Enum.filter(fn {_, stop} -> stop.location_type != :generic_node end)
        |> Enum.into(%{})
      end)

    Logger.info(
      "#{__MODULE__} unfiltered_child_stops_count=#{Enum.count(child_stops)} filtered_child_stops_count=#{Enum.count(result)} duration_ms=#{time_in_us / 1000}"
    )

    result
  end

  defp fetch_shape_data_for_map(stop_id) do
    {:ok,
     %{
       data: patterns,
       included: %{
         routes: routes_by_id,
         shapes: shapes_by_id,
         stops: stops_by_id,
         trips: trips_by_id
       }
     }} =
      Repository.route_patterns(
        filter: [stop: [stop_id]],
        include: [:route, representative_trip: [:shape, stops: :parent_station]]
      )

    Logger.info(
      "#{__MODULE__} route_patterns_count=#{Enum.count(patterns)} routes_count=#{Enum.count(routes_by_id)} trips_count=#{Enum.count(trips_by_id)} shapes_count=#{Enum.count(shapes_by_id)} stops_count=#{Enum.count(stops_by_id)}"
    )

    %{
      route_patterns: patterns,
      routes_by_id: routes_by_id,
      trips_by_id: trips_by_id,
      shapes_by_id: shapes_by_id,
      stops_by_id: stops_by_id
    }
  end
end

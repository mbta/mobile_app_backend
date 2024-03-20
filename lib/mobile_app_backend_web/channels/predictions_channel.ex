defmodule MobileAppBackendWeb.PredictionsChannel do
  use MobileAppBackendWeb, :channel

  alias MBTAV3API.Prediction

  @impl true
  def join("predictions:stops", payload, socket) do
    case Map.fetch(payload, "stop_ids") do
      {:ok, stop_ids} ->
        {:ok, %{included: %{stops: extra_stops}}} =
          MBTAV3API.Repository.stops(filter: [id: stop_ids], include: :child_stops)

        child_stop_ids =
          Map.values(extra_stops)
          |> Enum.filter(&(&1.location_type == :stop))
          |> Enum.map(& &1.id)

        stop_ids = Enum.uniq(stop_ids ++ child_stop_ids)

        {:ok, %{data: routes}} = MBTAV3API.Repository.routes(filter: [stop: stop_ids])

        data =
          Map.new(routes, fn %MBTAV3API.Route{id: route_id} ->
            {:ok, data} =
              MBTAV3API.Stream.StaticInstance.subscribe("predictions:route:#{route_id}")

            {route_id, data}
          end)

        {:ok, filter_data(data, stop_ids), assign(socket, data: data, stop_ids: stop_ids)}

      :error ->
        {:error, %{code: :no_stop_ids}}
    end
  end

  @impl true
  def handle_info({:stream_data, "predictions:route:" <> route_id, data}, socket) do
    data = put_in(socket.assigns.data, [route_id], data)
    socket = assign(socket, data: data)
    :ok = push(socket, "stream_data", filter_data(data, socket.assigns.stop_ids))
    {:noreply, socket}
  end

  defp filter_data(data, stop_ids) do
    data
    |> Enum.map(fn {_route_id, route_data} ->
      %{predictions: predictions, trip_ids: trip_ids, vehicle_ids: vehicle_ids} =
        for {_, %Prediction{} = prediction} <- route_data.predictions,
            reduce: %{predictions: %{}, trip_ids: [], vehicle_ids: []} do
          %{predictions: predictions, trip_ids: trip_ids, vehicle_ids: vehicle_ids} ->
            if prediction.stop_id in stop_ids do
              %{
                predictions: Map.put(predictions, prediction.id, prediction),
                trip_ids: [prediction.trip_id | trip_ids],
                vehicle_ids: [prediction.vehicle_id | vehicle_ids]
              }
            else
              %{predictions: predictions, trip_ids: trip_ids, vehicle_ids: vehicle_ids}
            end
        end

      %{
        predictions: predictions,
        trips: Map.take(route_data.trips, trip_ids),
        vehicles: Map.take(route_data.vehicles, vehicle_ids)
      }
    end)
    |> Enum.reduce(%{predictions: %{}, trips: %{}, vehicles: %{}}, fn data1, data2 ->
      Map.merge(data1, data2, fn _type, objs1, objs2 -> Map.merge(objs1, objs2) end)
    end)
  end
end

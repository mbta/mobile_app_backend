defmodule MobileAppBackendWeb.PredictionsChannel do
  use MobileAppBackendWeb, :channel

  alias MBTAV3API.JsonApi
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

            {route_id, filter_data(data, stop_ids)}
          end)

        {:ok, merge_data(data), assign(socket, data: data, stop_ids: stop_ids)}

      :error ->
        {:error, %{code: :no_stop_ids}}
    end
  end

  @impl true
  def handle_info({:stream_data, "predictions:route:" <> route_id, data}, socket) do
    data = put_in(socket.assigns.data, [route_id], filter_data(data, socket.assigns.stop_ids))
    socket = assign(socket, data: data)
    :ok = push(socket, "stream_data", merge_data(data))
    {:noreply, socket}
  end

  @doc """
  Filters the given data to predictions that are at one of the listed stops and the associated trips and vehicles.
  """
  @spec filter_data(JsonApi.Object.full_map(), [String.t()]) :: JsonApi.Object.full_map()
  def filter_data(route_data, stop_ids) do
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
      JsonApi.Object.to_full_map([])
      | predictions: predictions,
        trips: Map.take(route_data.trips, trip_ids),
        vehicles: Map.take(route_data.vehicles, vehicle_ids)
    }
  end

  @spec merge_data(%{String.t() => JsonApi.Object.full_map()}) :: JsonApi.Object.full_map()
  defp merge_data(data) do
    data
    |> Map.values()
    |> Enum.reduce(JsonApi.Object.to_full_map([]), &JsonApi.Object.merge_full_map/2)
  end
end

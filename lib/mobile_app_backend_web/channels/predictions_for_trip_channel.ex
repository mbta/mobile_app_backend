defmodule MobileAppBackendWeb.PredictionsForTripChannel do
  use MobileAppBackendWeb, :channel

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction

  @throttle_ms 500

  @impl true
  def join("predictions:trip:" <> trip_id, _payload, socket) do
    {:ok, throttler} =
      MobileAppBackend.Throttler.start_link(
        target: self(),
        cast: :send_data,
        ms: @throttle_ms
      )

    {:ok, %{data: [trip]}} = MBTAV3API.Repository.trips(filter: [id: trip_id])

    route_id = trip.route_id

    {:ok, data} = MBTAV3API.Stream.StaticInstance.subscribe("predictions:route:#{route_id}")

    data = filter_data(data, trip_id)

    {:ok, data, assign(socket, data: data, trip_id: trip_id, throttler: throttler)}
  end

  @impl true
  def handle_info({:stream_data, "predictions:route:" <> _route_id, data}, socket) do
    old_data = socket.assigns.data
    new_data = filter_data(data, socket.assigns.trip_id)

    if old_data != new_data do
      MobileAppBackend.Throttler.request(socket.assigns.throttler)
    end

    socket = assign(socket, data: new_data)
    {:noreply, socket}
  end

  @impl true
  def handle_cast(:send_data, socket) do
    :ok = push(socket, "stream_data", socket.assigns.data)
    {:noreply, socket}
  end

  @doc """
  Filters the given data to predictions that are at one of the listed stops and the associated trips and vehicles.
  """
  @spec filter_data(JsonApi.Object.full_map(), String.t()) :: JsonApi.Object.full_map()
  def filter_data(route_data, trip_id) do
    %{predictions: predictions, vehicle_ids: vehicle_ids} =
      for {_, %Prediction{} = prediction} <- route_data.predictions,
          reduce: %{predictions: %{}, vehicle_ids: []} do
        %{predictions: predictions, vehicle_ids: vehicle_ids} ->
          if prediction.trip_id == trip_id do
            %{
              predictions: Map.put(predictions, prediction.id, prediction),
              vehicle_ids: [prediction.vehicle_id | vehicle_ids]
            }
          else
            %{predictions: predictions, vehicle_ids: vehicle_ids}
          end
      end

    %{
      JsonApi.Object.to_full_map([])
      | predictions: predictions,
        trips: Map.take(route_data.trips, [trip_id]),
        vehicles: Map.take(route_data.vehicles, vehicle_ids)
    }
  end
end

defmodule MobileAppBackendWeb.PredictionsChannel do
  use MobileAppBackendWeb, :channel

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Prediction
  alias MBTAV3API.Trip
  alias MBTAV3API.Vehicle

  @impl true
  def join("predictions:stops", payload, socket) do
    case Map.fetch(payload, "stop_ids") do
      {:ok, stop_ids} ->
        case Prediction.stream_all(filter: [stop: stop_ids], include: [:trip, :vehicle]) do
          {:ok, stream_instance} ->
            {:ok, assign(socket, :stream_instance, stream_instance)}

          {:error, error} ->
            {:error, %{code: error}}
        end

      :error ->
        {:error, %{code: :no_stop_ids}}
    end
  end

  @impl true
  def terminate(reason, socket) do
    MBTAV3API.Stream.Instance.shutdown(socket.assigns[:stream_instance], reason)
  end

  @impl true
  def handle_info({:stream_data, predictions}, socket) do
    predictions =
      Enum.map(
        predictions,
        &%Prediction{
          &1
          | vehicle:
              case &1.vehicle do
                nil ->
                  nil

                %JsonApi.Reference{} = vehicle ->
                  vehicle

                %Vehicle{} = vehicle ->
                  %Vehicle{
                    vehicle
                    | trip:
                        case vehicle.trip do
                          nil -> nil
                          %JsonApi.Reference{} = vehicle_trip -> vehicle_trip
                          %Trip{id: trip_id} -> %JsonApi.Reference{type: "trip", id: trip_id}
                        end
                  }
              end
        }
      )

    :ok = push(socket, "stream_data", %{predictions: predictions})
    {:noreply, socket}
  end
end

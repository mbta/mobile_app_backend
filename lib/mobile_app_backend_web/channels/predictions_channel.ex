defmodule MobileAppBackendWeb.PredictionsChannel do
  use MobileAppBackendWeb, :channel

  alias MBTAV3API.Prediction

  @impl true
  def join("predictions:stops", payload, socket) do
    case Map.fetch(payload, "stop_ids") do
      {:ok, stop_ids} ->
        case Prediction.stream_all(filter: [stop: stop_ids], include: :trip) do
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
  def handle_info({:stream_events, events}, socket) do
    :ok = push(socket, "stream_events", %{events: events})
    {:noreply, socket}
  end
end

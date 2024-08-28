defmodule MobileAppBackendWeb.PredictionsForStopsV2Channel do
  use MobileAppBackendWeb, :channel
  require Logger

  alias MBTAV3API.JsonApi

  def join("predictions:stops:v2:" <> stop_id_concat, _payload, socket) do
    if stop_id_concat == "" do
      {:error, %{code: :no_stop_ids}}
    else
      stop_ids = String.split(stop_id_concat, ",")

      initial_data =
        Map.new(stop_ids, fn stop_id ->
          {:ok, data} = MobileAppBackend.StopPredictions.PubSub.subscribe(stop_id)
          {stop_id, data}
        end)

      {:ok, merge_data(initial_data), socket}
    end
  end

  @impl true
  def handle_info({:new_predictions, new_predictions_for_stop}, socket) do
    :ok = push(socket, "stream_data", new_predictions_for_stop)
    {:noreply, socket}
  end

  @spec merge_data(%{String.t() => JsonApi.Object.full_map()}) :: JsonApi.Object.full_map()
  defp merge_data(data) do
    data
    |> Map.values()
    |> Enum.reduce(JsonApi.Object.to_full_map([]), &JsonApi.Object.merge_full_map/2)
  end
end

defmodule MobileAppBackendWeb.PredictionsForStopsV2Channel do
  use MobileAppBackendWeb, :channel
  require Logger

  @impl true
  def join("predictions:stops:v2:" <> stop_id_concat, _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Predictions.PubSub,
        MobileAppBackend.Predictions.PubSub
      )

    if stop_id_concat == "" do
      {:error, %{code: :no_stop_ids}}
    else
      {time_micros, initial_data} =
        :timer.tc(fn ->
          stop_id_concat
          |> String.split(",")
          |> pubsub_module.subscribe_for_stops()
        end)

      Logger.info("#{__MODULE__} join duration=#{time_micros / 1000}")

      {:ok, initial_data, socket}
    end
  end

  @impl true
  @spec handle_info({:new_predictions, any()}, Phoenix.Socket.t()) ::
          {:noreply, Phoenix.Socket.t()}
  def handle_info({:new_predictions, new_predictions_for_stop}, socket) do
    {time_micros, _result} =
      :timer.tc(fn ->
        :ok = push(socket, "stream_data", new_predictions_for_stop)
      end)

    Logger.info("#{__MODULE__} push duration=#{time_micros / 1000}")

    require Logger
    {:noreply, socket}
  end
end

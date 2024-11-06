defmodule MobileAppBackendWeb.PredictionsForTripChannel do
  use MobileAppBackendWeb, :channel
  require Logger

  @impl true
  def join("predictions:trip:" <> trip_id, _payload, socket) do
    if trip_id == "" do
      {:error, %{code: :no_trip_id}}
    else
      subscribe(trip_id, socket)
    end
  end

  defp subscribe(trip_id, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Predictions.PubSub,
        MobileAppBackend.Predictions.PubSub
      )

    case :timer.tc(fn -> pubsub_module.subscribe_for_trip(trip_id) end) do
      {time_micros, :error} ->
        Logger.warning("#{__MODULE__} failed join duration=#{time_micros / 1000}")
        {:error, %{code: :subscribe_failed}}

      {time_micros, initial_data} ->
        Logger.info("#{__MODULE__} join duration=#{time_micros / 1000}")

        {:ok, initial_data, socket}
    end
  end

  @impl true
  @spec handle_info({:new_predictions, any()}, Phoenix.Socket.t()) ::
          {:noreply, Phoenix.Socket.t()}
  def handle_info({:new_predictions, new_predictions_for_trip}, socket) do
    {time_micros, _result} =
      :timer.tc(fn ->
        :ok = push(socket, "stream_data", new_predictions_for_trip)
      end)

    Logger.info("#{__MODULE__} push duration=#{time_micros / 1000}")

    require Logger
    {:noreply, socket}
  end
end

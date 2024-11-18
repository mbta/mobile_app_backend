defmodule MobileAppBackendWeb.AlertsChannel do
  alias MobileAppBackend.Alerts
  use MobileAppBackendWeb, :channel

  @impl true
  def join("alerts", _payload, socket) do
    alerts_data = Alerts.PubSub.subscribe()
    {:ok, alerts_data, socket}
  end

  @impl true
  def handle_info({:stream_data, "alerts", data}, socket) do
    :ok = push(socket, "stream_data", data)
    {:noreply, socket}
  end
end

defmodule MobileAppBackendWeb.AlertsChannel do
  use MobileAppBackendWeb, :channel

  @impl true
  def join("alerts", _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Alerts.PubSub,
        MobileAppBackend.Alerts.PubSub
      )

    data = pubsub_module.subscribe(legacy_compatibility: true)
    {:ok, data, socket}
  end

  @impl true
  def join("alerts:v2", _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Alerts.PubSub,
        MobileAppBackend.Alerts.PubSub
      )

    data = pubsub_module.subscribe(legacy_compatibility: false)
    {:ok, data, socket}
  end

  @impl true
  def handle_info({:new_alerts, data}, socket) do
    :ok = push(socket, "stream_data", data)
    {:noreply, socket}
  end
end

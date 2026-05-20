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
    {:ok, add_stale_alert_list(data), socket}
  end

  @impl true
  def handle_info({:new_alerts, data}, socket) do
    :ok = push(socket, "stream_data", add_stale_alert_list(data))
    {:noreply, socket}
  end

  # Hardcoded list of long term alerts that we expect affected riders to be aware
  # of. Used to limit cases where the alert is shown to reduce noise.
  defp add_stale_alert_list(data) do
    # TODO: remove this fake alert
    Map.put(data, :stale_alerts, ["1002418"])
  end
end

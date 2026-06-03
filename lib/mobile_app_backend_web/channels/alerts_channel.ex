defmodule MobileAppBackendWeb.AlertsChannel do
  use MobileAppBackendWeb, :channel

  @impl true
  def join("alerts" = topic, _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Alerts.PubSub,
        MobileAppBackend.Alerts.PubSub
      )

    data = pubsub_module.subscribe(get_opts(topic, socket))
    {:ok, data, socket}
  end

  @impl true
  def join("alerts:v2" = topic, _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Alerts.PubSub,
        MobileAppBackend.Alerts.PubSub
      )

    data = pubsub_module.subscribe(get_opts(topic, socket))
    {:ok, data, socket}
  end

  @impl true
  def join("alerts:v3" = topic, _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Alerts.PubSub,
        MobileAppBackend.Alerts.PubSub
      )

    data = pubsub_module.subscribe(get_opts(topic, socket))
    {:ok, data, socket}
  end

  defp get_opts(topic, socket) do
    case topic do
      "alerts" ->
        [legacy_compatibility: true, include_summaries: false]

      "alerts:v2" ->
        [legacy_compatibility: false, include_summaries: false]

      "alerts:v3" ->
        Keyword.merge(
          [legacy_compatibility: false, include_summaries: true],
          case Map.get(socket.assigns, :locale) do
            nil -> []
            locale -> [locale: locale]
          end
        )
    end
  end

  @impl true
  def handle_info({:new_alerts, data}, socket) do
    :ok = push(socket, "stream_data", data)
    {:noreply, socket}
  end
end

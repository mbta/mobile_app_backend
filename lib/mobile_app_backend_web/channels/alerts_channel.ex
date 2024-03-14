defmodule MobileAppBackendWeb.AlertsChannel do
  use MobileAppBackendWeb, :channel

  @impl true
  def join("alerts", _payload, socket) do
    case MBTAV3API.Stream.StaticInstance.subscribe("alerts") do
      {:ok, data} -> {:ok, data, socket}
      {:error, error} -> {:error, %{code: error}}
    end
  end

  @impl true
  def handle_info({:stream_data, data}, socket) do
    :ok = push(socket, "stream_data", data)
    {:noreply, socket}
  end
end

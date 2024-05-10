defmodule MobileAppBackendWeb.VehicleChannel do
  use MobileAppBackendWeb, :channel

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Vehicle

  @throttle_ms 500

  @impl true
  def join("vehicle:id:" <> vehicle_id, _payload, socket) do
    {:ok, throttler} =
      MobileAppBackend.Throttler.start_link(target: self(), cast: :send_data, ms: @throttle_ms)

    {:ok, vehicle_data} = MBTAV3API.Stream.StaticInstance.subscribe("vehicles")

    vehicle_data = filter_data(vehicle_data, vehicle_id)

    {:ok, vehicle_data,
     assign(socket,
       data: vehicle_data,
       vehicle_id: vehicle_id,
       throttler: throttler
     )}
  end

  @impl true
  def handle_info({:stream_data, "vehicles", all_vehicles_data}, socket) do
    old_data = socket.assigns.data
    new_data = filter_data(all_vehicles_data, socket.assigns.vehicle_id)

    if old_data != new_data do
      MobileAppBackend.Throttler.request(socket.assigns.throttler)
    end

    socket = assign(socket, data: new_data)
    {:noreply, socket}
  end

  @impl true
  def handle_cast(:send_data, socket) do
    :ok = push(socket, "stream_data", socket.assigns.data)
    {:noreply, socket}
  end

  @spec filter_data(JsonApi.Object.full_map(), String.t()) :: Vehicle
  defp filter_data(all_vehicles_data, vehicle_id) do
    %{vehicle: Map.get(all_vehicles_data.vehicles, vehicle_id)}
  end
end

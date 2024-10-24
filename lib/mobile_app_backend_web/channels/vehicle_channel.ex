defmodule MobileAppBackendWeb.VehicleChannel do
  use MobileAppBackendWeb, :channel

  @impl true
  def join("vehicle:id:" <> vehicle_id, _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Vehicles.PubSub,
        MobileAppBackend.Vehicles.PubSub
      )

    vehicle = pubsub_module.subscribe(vehicle_id)

    {:ok, %{vehicle: vehicle}, socket}
  end

  @impl true
  def handle_info({:new_vehicles, vehicle}, socket) do
    :ok = push(socket, "stream_data", %{vehicle: vehicle})
    {:noreply, socket}
  end
end

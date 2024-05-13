defmodule MobileAppBackendWeb.VehiclesChannel do
  use MobileAppBackendWeb, :channel

  alias MBTAV3API.JsonApi
  alias MBTAV3API.Vehicle

  @throttle_ms 500

  @impl true
  def join("vehicles:route", payload, socket) do
    with {:ok, route_id} <- Map.fetch(payload, "route_id"),
         {:ok, direction_id} <- Map.fetch(payload, "direction_id") do
      {:ok, throttler} =
        MobileAppBackend.Throttler.start_link(target: self(), cast: :send_data, ms: @throttle_ms)

      {:ok, vehicle_data} = MBTAV3API.Stream.StaticInstance.subscribe("vehicles")

      vehicle_data = filter_data(vehicle_data, route_id, direction_id)

      {:ok, vehicle_data,
       assign(socket,
         data: vehicle_data,
         route_id: route_id,
         direction_id: direction_id,
         throttler: throttler
       )}
    else
      :error -> {:error, %{code: :missing_param}}
    end
  end

  @impl true
  def handle_info({:stream_data, "vehicles", data}, socket) do
    old_data = socket.assigns.data
    new_data = filter_data(data, socket.assigns.route_id, socket.assigns.direction_id)

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

  @spec filter_data(JsonApi.Object.full_map(), String.t(), 0 | 1) :: JsonApi.Object.full_map()
  defp filter_data(vehicle_data, route_id, direction_id) do
    update_in(vehicle_data.vehicles, fn vehicles ->
      Map.filter(vehicles, fn {_, %Vehicle{} = vehicle} ->
        vehicle.route_id == route_id and vehicle.direction_id == direction_id
      end)
    end)
  end
end

defmodule MobileAppBackendWeb.VehiclesForRouteChannel do
  use MobileAppBackendWeb, :channel
  alias MBTAV3API.JsonApi.Object

  @impl true
  def join("vehicles:route", payload, socket) do
    with {:ok, route_id} <- Map.fetch(payload, "route_id"),
         {:ok, direction_id} <- Map.fetch(payload, "direction_id") do
      join_for_routes([route_id], direction_id, socket)
    else
      :error -> {:error, %{code: :missing_param}}
    end
  end

  @impl true
  def join("vehicles:routes:" <> topic_param_concat, _payload, socket) do
    case parse_params(topic_param_concat) do
      {:ok, route_ids, direction_id} ->
        join_for_routes(route_ids, direction_id, socket)

      _ ->
        {:error, %{code: :missing_param}}
    end
  end

  defp join_for_routes(route_ids, direction_id, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Vehicles.PubSub,
        MobileAppBackend.Vehicles.PubSub
      )

    vehicles = pubsub_module.subscribe_for_routes(route_ids, direction_id)

    {:ok, Object.to_full_map(vehicles), socket}
  end

  @impl true
  def handle_info({:new_vehicles, data}, socket) do
    :ok = push(socket, "stream_data", Object.to_full_map(data))
    {:noreply, socket}
  end

  @spec parse_params(String.t()) :: {:ok, [String.t()], 0 | 1} | :error
  defp parse_params(param_string) do
    if param_string == "" || !String.contains?(param_string, ":") do
      :error
    else
      [route_string, direction_string] = String.split(param_string, ":", parts: 2)

      case Integer.parse(direction_string) do
        {direction_id, _} when direction_id in [0, 1] ->
          {:ok, String.split(route_string, ","), direction_id}

        _ ->
          :error
      end
    end
  end
end

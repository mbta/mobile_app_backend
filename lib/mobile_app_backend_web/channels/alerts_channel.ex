defmodule MobileAppBackendWeb.AlertsChannel do
  use MobileAppBackendWeb, :channel

  defmodule AlertUpdate do
    @type t :: %__MODULE__{
            remove: [String.t()],
            update: %{String.t() => Alert.t() | AlertWithSummaries.t()}
          }
    @derive Jason.Encoder
    defstruct [:remove, :update]

    def empty?(update) do
      Enum.empty?(update.remove) and Enum.empty?(update.update)
    end
  end

  @impl true
  def join("alerts", _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Alerts.PubSub,
        MobileAppBackend.Alerts.PubSub
      )

    data = pubsub_module.subscribe(get_opts(socket))
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

    data = pubsub_module.subscribe(get_opts(socket))
    {:ok, data, socket}
  end

  @impl true
  def join("alerts:v3", _payload, socket) do
    pubsub_module =
      Application.get_env(
        :mobile_app_backend,
        MobileAppBackend.Alerts.PubSub,
        MobileAppBackend.Alerts.PubSub
      )

    %{alerts: alerts} = pubsub_module.subscribe(get_opts(socket))
    socket = assign(socket, :last_alerts, alert_hashes(alerts))

    {:ok, %AlertUpdate{remove: [], update: alerts}, socket}
  end

  defp get_opts(socket) do
    case socket.topic do
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
    case socket.topic do
      "alerts:v3" ->
        {:noreply, handle_info_v3({:new_alerts, data}, socket)}

      _ ->
        :ok = push(socket, "stream_data", data)
        {:noreply, socket}
    end
  end

  defp handle_info_v3({:new_alerts, %{alerts: alerts}}, socket) do
    current_hashes = alert_hashes(alerts)
    old_hashes = socket.assigns.last_alerts

    current_ids = MapSet.new(Map.keys(current_hashes))
    old_ids = MapSet.new(Map.keys(old_hashes))

    removed_ids = MapSet.difference(old_ids, current_ids)
    new_ids = MapSet.difference(current_ids, old_ids)

    update_ids =
      current_ids
      |> MapSet.intersection(old_ids)
      |> MapSet.filter(fn id -> Map.get(current_hashes, id) != Map.get(old_hashes, id) end)
      |> MapSet.union(new_ids)

    response =
      %AlertUpdate{
        remove: MapSet.to_list(removed_ids),
        update: Map.filter(alerts, fn {id, _alert} -> Enum.member?(update_ids, id) end)
      }

    if !AlertUpdate.empty?(response) do
      :ok = push(socket, "stream_data", response)
    end

    assign(socket, :last_alerts, current_hashes)
  end

  defp alert_hashes(alert_map) do
    Map.new(alert_map, fn {key, val} ->
      {key,
       val
       |> Map.from_struct()
       |> Enum.sort_by(fn {key, _value} -> key end)
       |> Enum.map(fn {key, value} ->
         case key do
           # Do some hacky sorting of informed entities, since the backend can return them arbitrarily in any order
           :informed_entity ->
             {key,
              Enum.sort_by(value, fn entity ->
                "#{entity.route}-#{entity.stop}-#{entity.direction_id}-#{entity.route_type}-#{entity.facility}-#{entity.trip}"
              end)}

           # Summaries can also change order based on the entity order, so sort those too
           :summaries ->
             {key, Enum.sort_by(value, fn summary -> summary.summary end)}

           _ ->
             {key, value}
         end
       end)
       |> :erlang.term_to_binary()
       |> then(&:crypto.hash(:md5, &1))
       |> Base.encode16()}
    end)
  end
end

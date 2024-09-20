defmodule MobileAppBackend.Predictions.StreamSubscriber do
  @moduledoc """
  Ensure that prediction streams from the V3 API have been started for
  each route relevant to a subscriber. Once the streams have been started,
  prediction updates will be sent to `Store.Predictions`.
  """
  alias MBTAV3API.Stop
  alias MobileAppBackend.Predictions.StreamSubscriber

  @doc """
  Ensure prediction streams have been started for every route served by the given stops.
  """
  @callback subscribe_for_stops([Stop.id()]) :: :ok

  def subscribe_for_stops(stop_ids) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.Predictions.StreamSubscriber,
      StreamSubscriber.Impl
    ).subscribe_for_stops(stop_ids)
  end
end

defmodule MobileAppBackend.Predictions.StreamSubscriber.Impl do
  @moduledoc """
  Ensure that prediction streams from the V3 API have been started for
  each route relevant to a subscriber. Once the streams have been started,
  prediction updates will be sent to `Store.Predictions`. and vehicle updates
  will be sent to `Store.Vehicles`.

  """
  @behaviour MobileAppBackend.Predictions.StreamSubscriber

  alias MBTAV3API.Stop
  alias MBTAV3API.Stream.StaticInstance

  @spec subscribe_for_stops([Stop.id()]) :: :ok
  @doc """
  Ensure prediction streams have been started for every route served by the given stops
  and the stream of all vehicles has been started.
  """
  def subscribe_for_stops(stop_ids) do
    {:ok, %{data: routes}} = MBTAV3API.Repository.routes(filter: [stop: stop_ids])

    Enum.each(routes, fn %MBTAV3API.Route{id: route_id} ->
      {:ok, _data} =
        StaticInstance.subscribe("predictions:route:to_store:#{route_id}",
          include_current_data: false
        )
    end)

    StaticInstance.ensure_stream_started("vehicles:to_store", include_current_data: false)
  end
end

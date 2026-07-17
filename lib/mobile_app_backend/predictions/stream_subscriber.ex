defmodule MobileAppBackend.Predictions.StreamSubscriber do
  @moduledoc """
  Ensure that prediction streams from the V3 API have been started for
  each route relevant to a subscriber. Once the streams have been started,
  prediction updates will be sent to `Store.Predictions`. and vehicle updates
  will be sent to `Store.Vehicles`.

  """
  alias MBTAV3API.Stop
  alias MBTAV3API.Trip
  alias MobileAppBackend.Predictions.StreamSubscriber

  @doc """
  Ensure prediction streams have been started for every route served by the given stops
  and the stream of all vehicles has been started.
  """
  @callback subscribe_for_stops([Stop.id()]) :: :ok | :error
  def subscribe_for_stops(stop_ids) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.Predictions.StreamSubscriber,
      StreamSubscriber.Impl
    ).subscribe_for_stops(stop_ids)
  end

  @callback subscribe_for_trip(Trip.id()) :: :ok | :error
  def subscribe_for_trip(trip_id) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.Predictions.StreamSubscriber,
      StreamSubscriber.Impl
    ).subscribe_for_trip(trip_id)
  end
end

defmodule MobileAppBackend.Predictions.StreamSubscriber.Impl do
  @behaviour MobileAppBackend.Predictions.StreamSubscriber

  alias MBTAV3API.Stream.StaticInstance
  alias MobileAppBackend.GlobalDataCache

  require Logger

  @impl true
  def subscribe_for_stops(stop_ids) do
    case GlobalDataCache.route_ids_for_stops(stop_ids) do
      :error ->
        Logger.error("#{__MODULE__} failed to fetch route_ids_for_stops from global data")
        :error

      route_ids ->
        Enum.each(route_ids, fn route_id ->
          {:ok, _data} =
            StaticInstance.ensure_stream_started("predictions:route:to_store:#{route_id}",
              include_current_data: false
            )
        end)

        {:ok, _data} =
          StaticInstance.ensure_stream_started("vehicles:to_store", include_current_data: false)

        :ok
    end
  end

  @impl true
  def subscribe_for_trip(trip_id) do
    with {:ok, %{data: [trip]}} <- MBTAV3API.Repository.trips(filter: [id: trip_id]),
         {:ok, route_id} <-
           if(trip.route_id, do: {:ok, trip.route_id}, else: {:error, :missing_route_id}),
         {:ok, _data} <-
           StaticInstance.ensure_stream_started("predictions:route:to_store:#{route_id}",
             include_current_data: false
           ),
         {:ok, _data} <-
           StaticInstance.ensure_stream_started("vehicles:to_store", include_current_data: false) do
      :ok
    else
      {:ok, %{data: []}} ->
        log_failed_trip_fetch(trip_id, :trip_not_found)

        :error

      {:error, :missing_route_id} ->
        log_failed_trip_fetch(trip_id, :missing_route_id)

        :error

      {:error, reason} ->
        log_failed_trip_fetch(trip_id, reason)

        :error

      _ ->
        log_failed_trip_fetch(trip_id, :unknown_error)
        :error
    end
  end

  defp log_failed_trip_fetch(trip_id, reason) do
    Logger.warning(
      "#{__MODULE__} failed to fetch trip from repository for trip=#{trip_id}. Reason: #{inspect(reason)}"
    )
  end
end

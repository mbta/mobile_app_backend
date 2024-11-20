defmodule MobileAppBackend.Predictions.StreamSubscriberTest do
  use ExUnit.Case

  alias MobileAppBackend.Predictions.StreamSubscriber
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "subscribe_for_stops/1" do
    setup do
      verify_on_exit!()

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.GlobalDataCache.Module,
        GlobalDataCacheMock
      )

      reassign_env(:mobile_app_backend, MBTAV3API.Stream.StaticInstance, StaticInstanceMock)
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "starts streams for to the routes served at the given stops and vehicles" do
      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:route_ids_for_stops, fn _, _ -> ["66", "39"] end)

      StaticInstanceMock
      |> expect(:ensure_stream_started, fn "predictions:route:to_store:66",
                                           include_current_data: false ->
        {:ok, :no_data}
      end)
      |> expect(:ensure_stream_started, fn "predictions:route:to_store:39",
                                           include_current_data: false ->
        {:ok, :no_data}
      end)
      |> expect(:ensure_stream_started, fn "vehicles:to_store", include_current_data: false ->
        {:ok, :no_data}
      end)

      StreamSubscriber.subscribe_for_stops([1, 2])
    end
  end

  describe "subscribe_for_trip/1" do
    setup do
      verify_on_exit!()

      reassign_env(
        :mobile_app_backend,
        MobileAppBackend.GlobalDataCache.Module,
        GlobalDataCacheMock
      )

      reassign_env(:mobile_app_backend, MBTAV3API.Stream.StaticInstance, StaticInstanceMock)
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "starts streams for to the routes served at the given stops and vehicles" do
      trip = build(:trip, id: "trip", route_id: "66")

      RepositoryMock
      |> expect(:trips, fn _, _ -> {:ok, %{data: [trip]}} end)

      StaticInstanceMock
      |> expect(:ensure_stream_started, fn "predictions:route:to_store:66",
                                           include_current_data: false ->
        {:ok, :no_data}
      end)
      |> expect(:ensure_stream_started, fn "vehicles:to_store", include_current_data: false ->
        {:ok, :no_data}
      end)

      StreamSubscriber.subscribe_for_trip("trip")
    end
  end
end

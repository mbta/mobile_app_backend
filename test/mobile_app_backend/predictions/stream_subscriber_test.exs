defmodule MobileAppBackend.Predictions.StreamSubscriberTest do
  use ExUnit.Case

  alias MobileAppBackend.Predictions.StreamSubscriber
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  describe "subscribe_for_stops/1" do
    setup do
      verify_on_exit!()
      reassign_env(:mobile_app_backend, MBTAV3API.Stream.StaticInstance, StaticInstanceMock)
      reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    end

    test "subscribes to the routes served at the given stops" do
      expect(RepositoryMock, :routes, fn _, _ ->
        ok_response([build(:route, id: "66"), build(:route, id: "39")])
      end)

      StaticInstanceMock
      |> expect(:subscribe, fn "predictions:route:to_store:66", include_current_data: false ->
        {:ok, :no_data}
      end)
      |> expect(:subscribe, fn "predictions:route:to_store:39", include_current_data: false ->
        {:ok, :no_data}
      end)
      |> expect(:ensure_stream_started, fn "vehicles:to_store", include_current_data: false ->
        {:ok, :no_data}
      end)

      StreamSubscriber.subscribe_for_stops([1, 2])
    end
  end
end

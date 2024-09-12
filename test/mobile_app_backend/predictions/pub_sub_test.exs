defmodule MobileAppBackend.Predictions.PubSubTests do
  use ExUnit.Case

  alias MBTAV3API.{Store, Stream}
  alias MobileAppBackend.Predictions.{PubSub, StreamSubscriber}
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  setup do
    verify_on_exit!()
    reassign_env(:mobile_app_backend, StreamSubscriber, StreamSubscriberMock)
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    reassign_env(:mobile_app_backend, Store.Predictions, PredictionsStoreMock)
    :ok
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  describe "subscribe_for_stop/1" do
    test "returns initial data for the given isolated stop" do
      prediction_1 = build(:prediction, stop_id: "12345")
      prediction_2 = build(:prediction, stop_id: "12345")

      expect(PredictionsStoreMock, :fetch, fn _ -> [prediction_1, prediction_2] end)

      RepositoryMock
      |> expect(:stops, fn _, _ -> ok_response([build(:stop, id: "12345")]) end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      assert %{"12345" => [prediction_1, prediction_2]} == PubSub.subscribe_for_stop("12345")
    end

    test "returns initial data for the given parent stop" do
      prediction_1 = build(:prediction, stop_id: "12345", id: "1")
      prediction_2 = build(:prediction, stop_id: "6789", id: "2")

      expect(PredictionsStoreMock, :fetch, fn fetch_keyword_list ->
        assert Enum.any?(fetch_keyword_list, &(Keyword.get(&1, :stop_id) == "12345"))
        assert Enum.any?(fetch_keyword_list, &(Keyword.get(&1, :stop_id) == "6789"))
        [prediction_1, prediction_2]
      end)

      RepositoryMock
      |> expect(:stops, fn _, _ ->
        ok_response([build(:stop, id: "parent_stop_id")], [
          build(:stop, id: "12345", location_type: :stop, parent_station_id: "parent_stop_id"),
          build(:stop, id: "6789", location_type: :stop, parent_station_id: "parent_stop_id")
        ])
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      assert %{"parent_stop_id" => [prediction_1, prediction_2]} ==
               PubSub.subscribe_for_stop("parent_stop_id")
    end
  end

  describe "subscribe_for_stops/1" do
    test "returns initial data for each stop given" do
      prediction_1 = build(:prediction, stop_id: "standalone")
      prediction_2 = build(:prediction, stop_id: "child")

      expect(PredictionsStoreMock, :fetch, 2, fn keys ->
        case keys do
          [stop_id: "standalone"] -> [prediction_1]
          [[stop_id: "child"]] -> [prediction_2]
        end
      end)

      RepositoryMock
      |> expect(:stops, fn _, _ ->
        ok_response([build(:stop, id: "standalone")], [
          build(:stop, id: "child", parent_station_id: "parent")
        ])
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      assert %{"standalone" => [prediction_1], "parent" => [prediction_2]} ==
               PubSub.subscribe_for_stops(["parent", "standalone"])
    end
  end

  describe "handle_info" do
    setup do
      _dispatched_table = :ets.new(:test_last_dispatched, [:set, :named_table])
      {:ok, %{last_dispatched_table_name: :test_last_dispatched}}
    end

    test "broadcasts on :reset_event" do
      PubSub.handle_info(:reset_event, %{last_dispatched_table_name: :test_last_dispatched})
      assert_receive :broadcast
    end

    test ":broadcast sends message to subscribed pid", state do
      prediction_1 = build(:prediction, stop_id: "12345")
      prediction_2 = build(:prediction, stop_id: "12345")
      prediction_3 = build(:prediction, stop_id: "12345")

      PredictionsStoreMock
      # Subscribe
      |> expect(:fetch, fn _ -> [prediction_1] end)
      # 1st and 2nd broadcast
      |> expect(:fetch, 2, fn _ -> [prediction_2] end)
      # 3rd broadcast
      |> expect(:fetch, fn _ -> [prediction_3] end)

      RepositoryMock
      |> expect(:stops, fn _, _ ->
        ok_response([build(:stop, id: "12345")], [])
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      PubSub.subscribe_for_stop("12345")

      PubSub.handle_info(:broadcast, state)
      assert_receive {:new_predictions, %{"12345" => [^prediction_2]}}

      # Doesn't re-send the same predictions that have already been seen
      PubSub.handle_info(:broadcast, state)

      refute_receive _

      # Sends new predictions
      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_predictions, %{"12345" => [^prediction_3]}}
    end

    test "pid can be subscribed to multiple keys", state do
      prediction_1 = build(:prediction, stop_id: "12345")
      prediction_2 = build(:prediction, stop_id: "6789")

      PredictionsStoreMock
      |> expect(:fetch, 4, fn keys ->
        case keys do
          [stop_id: "12345"] -> [prediction_1]
          [stop_id: "6789"] -> [prediction_2]
        end
      end)

      RepositoryMock
      |> expect(:stops, 2, fn _, _ ->
        ok_response([], [])
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, 2, fn _ -> :ok end)

      PubSub.subscribe_for_stop("12345")
      PubSub.subscribe_for_stop("6789")

      PubSub.handle_info(:broadcast, state)
      assert_receive {:new_predictions, new_predictions}
      assert %{"12345" => [^prediction_1]} = new_predictions

      assert_receive {:new_predictions, new_predictions}
      assert %{"6789" => [^prediction_2]} = new_predictions
    end
  end

  describe "reset event e2e" do
    test "when a reset event is broadcast, subscribers are pushed latest predictions" do
      prediction_1 = build(:prediction, stop_id: "12345")

      expect(PredictionsStoreMock, :fetch, 2, fn _ -> [prediction_1] end)

      RepositoryMock
      |> expect(:stops, fn _, _ ->
        ok_response([build(:stop, id: "12345")], [])
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      PubSub.subscribe_for_stop("12345")

      Stream.PubSub.broadcast!("predictions:all:events", :reset_event)
      assert_receive {:new_predictions, %{"12345" => [^prediction_1]}}
    end
  end
end

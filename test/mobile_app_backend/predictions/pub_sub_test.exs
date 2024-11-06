defmodule MobileAppBackend.Predictions.PubSubTests do
  use ExUnit.Case

  alias MBTAV3API.JsonApi
  alias MBTAV3API.{Store, Stream}
  alias MobileAppBackend.Predictions.{PubSub, StreamSubscriber}
  import Mox
  import Test.Support.Helpers
  import MobileAppBackend.Factory

  setup do
    verify_on_exit!()

    reassign_env(
      :mobile_app_backend,
      MobileAppBackend.GlobalDataCache.Module,
      GlobalDataCacheMock
    )

    reassign_env(:mobile_app_backend, StreamSubscriber, StreamSubscriberMock)
    reassign_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)
    reassign_env(:mobile_app_backend, Store.Predictions, PredictionsStoreMock)
    :ok
  end

  # make sure mocks are globally accessible, including from the PubSub genserver
  setup :set_mox_from_context

  describe "init/1" do
    test "subscribes to vehicle events" do
      PubSub.init(create_table_fn: fn -> :no_op end)
      Stream.PubSub.broadcast!("vehicles:to_store", :reset_event)
      assert_receive :reset_event
    end

    test "subscribes to prediction events" do
      PubSub.init(create_table_fn: fn -> :no_op end)

      Stream.PubSub.broadcast!("predictions:all:events", :reset_event)
      assert_receive :reset_event
    end
  end

  describe "subscribe_for_stop/1" do
    test "returns initial data for the given isolated stop" do
      prediction_1 =
        build(:prediction, id: "p_1", stop_id: "12345", trip_id: "trip_1", vehicle_id: "v_1")

      prediction_2 =
        build(:prediction, id: "p_2", stop_id: "12345", trip_id: "trip_1", vehicle_id: "v_2")

      trip_1 = build(:trip, id: "trip_1")
      trip_2 = build(:trip, id: "trip_2")
      vehicle_1 = build(:vehicle, id: "v_1")
      vehicle_2 = build(:vehicle, id: "v_2")

      full_map =
        JsonApi.Object.to_full_map([
          prediction_1,
          prediction_2,
          trip_1,
          trip_2,
          vehicle_1,
          vehicle_2
        ])

      expect(PredictionsStoreMock, :fetch_with_associations, fn [[stop_id: "12345"]] ->
        full_map
      end)

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ -> %{stops: %{"12345" => build(:stop, id: "12345")}} end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      assert %{
               predictions_by_stop: %{"12345" => %{"p_1" => prediction_1, "p_2" => prediction_2}},
               trips: %{"trip_1" => trip_1, "trip_2" => trip_2},
               vehicles: %{"v_1" => vehicle_1, "v_2" => vehicle_2}
             } == PubSub.subscribe_for_stop("12345")
    end

    test "returns initial data for the given parent stop" do
      prediction_1 =
        build(:prediction, stop_id: "12345", id: "p_1", trip_id: "trip_1", vehicle_id: "v_1")

      prediction_2 =
        build(:prediction, stop_id: "6789", id: "p_2", trip_id: "trip_2", vehicle_id: "v_2")

      trip_1 = build(:trip, id: "trip_1")
      trip_2 = build(:trip, id: "trip_2")
      vehicle_1 = build(:vehicle, id: "v_1")
      vehicle_2 = build(:vehicle, id: "v_2")

      full_map =
        JsonApi.Object.to_full_map([
          prediction_1,
          prediction_2,
          trip_1,
          trip_2,
          vehicle_1,
          vehicle_2
        ])

      expect(PredictionsStoreMock, :fetch_with_associations, fn fetch_keyword_list ->
        assert Enum.any?(fetch_keyword_list, &(Keyword.get(&1, :stop_id) == "12345"))
        assert Enum.any?(fetch_keyword_list, &(Keyword.get(&1, :stop_id) == "6789"))
        full_map
      end)

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          stops: %{
            "parent_stop_id" =>
              build(:stop, id: "parent_stop_id", child_stop_ids: ["12345", "6789"]),
            "12345" =>
              build(:stop, id: "12345", location_type: :stop, parent_station_id: "parent_stop_id"),
            "6789" =>
              build(:stop, id: "6789", location_type: :stop, parent_station_id: "parent_stop_id")
          }
        }
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      assert %{
               predictions_by_stop: %{
                 "parent_stop_id" => %{"p_1" => prediction_1, "p_2" => prediction_2}
               },
               trips: %{"trip_1" => trip_1, "trip_2" => trip_2},
               vehicles: %{"v_1" => vehicle_1, "v_2" => vehicle_2}
             } ==
               PubSub.subscribe_for_stop("parent_stop_id")
    end
  end

  describe "subscribe_for_stops/1" do
    test "returns initial data for each stop given" do
      prediction_1 =
        build(:prediction, id: "p_1", stop_id: "standalone", trip_id: "trip_1", vehicle_id: "v_1")

      prediction_2 =
        build(:prediction, id: "p_2", stop_id: "child", trip_id: "trip_2", vehicle_id: "v_2")

      trip_1 = build(:trip, id: "trip_1")
      trip_2 = build(:trip, id: "trip_2")
      vehicle_1 = build(:vehicle, id: "v_1")
      vehicle_2 = build(:vehicle, id: "v_2")

      full_map =
        JsonApi.Object.to_full_map([
          prediction_1,
          prediction_2,
          trip_1,
          trip_2,
          vehicle_1,
          vehicle_2
        ])

      expect(PredictionsStoreMock, :fetch_with_associations, 1, fn [
                                                                     [stop_id: "child"],
                                                                     [stop_id: "standalone"]
                                                                   ] ->
        full_map
      end)

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          stops: %{
            "parent" => build(:stop, id: "parent", child_stop_ids: ["child"]),
            "child" => build(:stop, id: "child"),
            "standalone" => build(:stop, id: "standalone")
          }
        }
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      assert %{
               predictions_by_stop: %{
                 "standalone" => %{"p_1" => prediction_1},
                 "parent" => %{"p_2" => prediction_2}
               },
               trips: %{"trip_1" => trip_1, "trip_2" => trip_2},
               vehicles: %{"v_1" => vehicle_1, "v_2" => vehicle_2}
             } ==
               PubSub.subscribe_for_stops(["parent", "standalone"])
    end
  end

  describe "subscribe_for_trip/1" do
    test "returns initial data for the given trip" do
      prediction_1 =
        build(:prediction, id: "p_1", stop_id: "12345", trip_id: "trip_1", vehicle_id: "v_1")

      prediction_2 =
        build(:prediction, id: "p_2", stop_id: "67890", trip_id: "trip_1", vehicle_id: "v_1")

      trip_1 = build(:trip, id: "trip_1")
      vehicle_1 = build(:vehicle, id: "v_1")

      full_map =
        JsonApi.Object.to_full_map([
          prediction_1,
          prediction_2,
          trip_1,
          vehicle_1
        ])

      expect(PredictionsStoreMock, :fetch_with_associations, fn [trip_id: "trip_1"] ->
        full_map
      end)

      expect(StreamSubscriberMock, :subscribe_for_trip, fn _ -> :ok end)

      assert %{
               predictions: %{"p_1" => prediction_1, "p_2" => prediction_2},
               trips: %{"trip_1" => trip_1},
               vehicles: %{"v_1" => vehicle_1}
             } == PubSub.subscribe_for_trip("trip_1")
    end

    @tag :capture_log
    test "returns an error when subscriber fails" do
      expect(StreamSubscriberMock, :subscribe_for_trip, fn _ -> :error end)

      assert :error == PubSub.subscribe_for_trip("trip_1")
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
      prediction_1 = build(:prediction, stop_id: "12345", trip_id: "trip_1", vehicle_id: "v_1")
      prediction_2 = build(:prediction, stop_id: "12345", trip_id: "trip_1", vehicle_id: "v_1")
      prediction_3 = build(:prediction, stop_id: "12345", trip_id: "trip_1", vehicle_id: "v_1")
      trip_1 = build(:trip, id: "trip_1")
      vehicle_1 = build(:vehicle, id: "v_1")

      PredictionsStoreMock
      # Subscribe
      |> expect(:fetch_with_associations, fn _ ->
        JsonApi.Object.to_full_map([prediction_1, trip_1, vehicle_1])
      end)
      # 1st and 2nd broadcast
      |> expect(:fetch_with_associations, 2, fn _ ->
        JsonApi.Object.to_full_map([prediction_2, trip_1, vehicle_1])
      end)
      # 3rd broadcast
      |> expect(:fetch_with_associations, fn _ ->
        JsonApi.Object.to_full_map([prediction_3, trip_1, vehicle_1])
      end)

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          stops: %{
            "12345" => build(:stop, id: "12345")
          }
        }
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      PubSub.subscribe_for_stop("12345")

      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_predictions,
                      %{
                        stop_id: "12345",
                        predictions: predictions,
                        trips: trips,
                        vehicles: vehicles
                      }}

      assert %{prediction_2.id => prediction_2} == predictions
      assert %{trip_1.id => trip_1} == trips
      assert %{vehicle_1.id => vehicle_1} == vehicles

      # Doesn't re-send the same predictions that have already been seen
      PubSub.handle_info(:broadcast, state)

      refute_receive _

      # Sends new predictions
      PubSub.handle_info(:broadcast, state)

      assert_receive {:new_predictions,
                      %{stop_id: "12345", predictions: predictions, trips: trips}}

      assert %{prediction_3.id => prediction_3} == predictions
      assert %{trip_1.id => trip_1} == trips
    end

    test "pid can be subscribed to multiple keys", state do
      prediction_1 =
        build(:prediction,
          id: "prediction_1",
          stop_id: "12345",
          trip_id: "trip_1",
          vehicle_id: "v_1"
        )

      prediction_2 =
        build(:prediction,
          id: "prediction_2",
          stop_id: "6789",
          trip_id: "trip_2",
          vehicle_id: "v_2"
        )

      trip_1 = build(:trip, id: "trip_1")
      trip_2 = build(:trip, id: "trip_2")
      vehicle_1 = build(:vehicle, id: "v_1")
      vehicle_2 = build(:vehicle, id: "v_2")

      full_map_12345 = JsonApi.Object.to_full_map([prediction_1, trip_1, vehicle_1])
      full_map_6789 = JsonApi.Object.to_full_map([prediction_2, trip_2, vehicle_2])

      PredictionsStoreMock
      |> expect(:fetch_with_associations, fn [[stop_id: "12345"]] ->
        full_map_12345
      end)
      |> expect(:fetch_with_associations, fn [[stop_id: "6789"]] ->
        full_map_6789
      end)
      |> expect(:fetch_with_associations, fn [stop_id: "12345"] ->
        full_map_12345
      end)
      |> expect(:fetch_with_associations, fn [stop_id: "6789"] ->
        full_map_6789
      end)

      GlobalDataCacheMock
      |> expect(:default_key, 2, fn -> :default_key end)
      |> expect(:get_data, 2, fn _ ->
        %{
          stops: %{}
        }
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, 2, fn _ -> :ok end)

      PubSub.subscribe_for_stop("12345")
      PubSub.subscribe_for_stop("6789")

      PubSub.handle_info(:broadcast, state)
      assert_receive {:new_predictions, new_predictions}

      assert %{
               stop_id: "12345",
               predictions: %{"prediction_1" => ^prediction_1},
               trips: %{"trip_1" => ^trip_1},
               vehicles: %{"v_1" => ^vehicle_1}
             } = new_predictions

      assert_receive {:new_predictions, new_predictions}

      assert %{
               stop_id: "6789",
               predictions: %{"prediction_2" => ^prediction_2},
               trips: %{"trip_2" => ^trip_2},
               vehicles: %{"v_2" => ^vehicle_2}
             } = new_predictions
    end
  end

  describe "reset event e2e" do
    test "when a reset event is broadcast, subscribers are pushed latest predictions" do
      prediction_1 = build(:prediction, stop_id: "12345", trip_id: "trip_1")
      trip_1 = build(:trip, id: "trip_1")

      full_map = JsonApi.Object.to_full_map([prediction_1, trip_1])

      expect(PredictionsStoreMock, :fetch_with_associations, 2, fn _ -> full_map end)

      GlobalDataCacheMock
      |> expect(:default_key, fn -> :default_key end)
      |> expect(:get_data, fn _ ->
        %{
          stops: %{}
        }
      end)

      expect(StreamSubscriberMock, :subscribe_for_stops, fn _ -> :ok end)

      PubSub.subscribe_for_stop("12345")

      Stream.PubSub.broadcast!("predictions:all:events", :reset_event)
      assert_receive {:new_predictions, response}
      assert response == Map.put(full_map, :stop_id, "12345")
    end
  end
end

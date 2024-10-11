defmodule MBTAV3API.Store.PredictionsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Test.Support.Helpers
  import Test.Support.Sigils

  alias MBTAV3API.JsonApi
  alias MBTAV3API.{JsonApi.Reference, Store}

  setup do
    start_link_supervised!(Store.Predictions)
    start_link_supervised!(Store.Vehicles)

    %{
      prediction_1:
        build(:prediction, id: "1", stop_id: "12345", trip_id: "trip_1", vehicle_id: "v_1"),
      prediction_2:
        build(:prediction, id: "2", stop_id: "12345", trip_id: "trip_2", vehicle_id: "v_2"),
      trip_1: build(:trip, id: "trip_1"),
      trip_2: build(:trip, id: "trip_2"),
      vehicle_1: build(:vehicle, id: "v_1"),
      vehicle_2: build(:vehicle, id: "v_2")
    }
  end

  describe "process_events" do
    test "process_upsert when add", %{
      prediction_1: prediction_1,
      prediction_2: prediction_2,
      trip_1: trip_1,
      trip_2: trip_2
    } do
      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2, trip_1, trip_2])

      assert %{
               predictions: %{"1" => ^prediction_1, "2" => ^prediction_2},
               trips: %{"trip_1" => ^trip_1, "trip_2" => ^trip_2}
             } = Store.Predictions.fetch_with_associations(stop_id: "12345")
    end

    test "process_upsert when update", %{
      prediction_1: prediction_1,
      prediction_2: prediction_2,
      trip_1: trip_1,
      trip_2: trip_2
    } do
      prediction_1_update = %{prediction_1 | departure_time: ~B[2024-03-20 16:42:01]}

      trip_2_update = %{trip_2 | headsign: "new_headsign"}

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2, trip_1, trip_2])

      assert %{
               predictions: %{"1" => ^prediction_1, "2" => ^prediction_2},
               trips: %{"trip_1" => ^trip_1}
             } = Store.Predictions.fetch_with_associations(stop_id: "12345")

      Store.Predictions.process_upsert(:update, [prediction_1_update, trip_2_update])

      assert %{
               predictions: %{"1" => ^prediction_1_update, "2" => ^prediction_2},
               trips: %{"trip_1" => ^trip_1, "trip_2" => ^trip_2_update}
             } = Store.Predictions.fetch_with_associations(stop_id: "12345")
    end

    @tag :capture_log
    test "process_remove", %{
      prediction_1: prediction_1,
      prediction_2: prediction_2,
      trip_1: trip_1,
      trip_2: trip_2
    } do
      set_log_level(:info)

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2, trip_1, trip_2])

      msg =
        capture_log([level: :info], fn ->
          Store.Predictions.process_remove([
            %Reference{type: "prediction", id: prediction_1.id},
            %Reference{type: "trip", id: trip_1.id}
          ])
        end)

      assert msg =~ "process_remove %MBTAV3API.JsonApi.Reference{type: \"prediction\", id: \"1\"}"
      assert msg =~ "process_remove %MBTAV3API.JsonApi.Reference{type: \"trip\", id: \"trip_1\"}"

      assert JsonApi.Object.to_full_map([prediction_2, trip_2]) ==
               Store.Predictions.fetch_with_associations(stop_id: "12345")
    end

    test "process_reset" do
      prediction_66 =
        build(:prediction, id: "1", stop_id: "12345", route_id: "66", trip_id: "trip_1")

      prediction_66_2 =
        build(:prediction, id: "2", stop_id: "12345", route_id: "66", trip_id: "trip_2")

      prediction_39 =
        build(:prediction, id: "3", stop_id: "12345", route_id: "39", trip_id: "trip_3")

      trip_66 = build(:trip, id: "trip_1", route_id: "66")
      trip_66_2 = build(:trip, id: "trip_2", route_id: "66")
      trip_39 = build(:trip, id: "trip_3", route_id: "39")

      Store.Predictions.process_upsert(:add, [prediction_66, prediction_39, trip_66, trip_39])
      Store.Predictions.process_reset([prediction_66_2, trip_66_2], route_id: "66")

      assert JsonApi.Object.to_full_map([prediction_66_2, trip_66_2, prediction_39, trip_39]) ==
               Store.Predictions.fetch_with_associations(stop_id: "12345")
    end
  end

  describe "fetch" do
    test "by stop_id" do
      prediction_1 = build(:prediction, id: "1", stop_id: "12345")
      prediction_2 = build(:prediction, id: "2", stop_id: "6789")

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2])

      assert [prediction_1] ==
               Enum.sort_by(Store.Predictions.fetch(stop_id: "12345"), & &1.id)
    end

    test "by route_id" do
      prediction_1 = build(:prediction, id: "1", route_id: "66")
      prediction_2 = build(:prediction, id: "2", route_id: "39")

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2])

      assert [prediction_1] ==
               Enum.sort_by(Store.Predictions.fetch(route_id: "66"), & &1.id)
    end

    test "by trip_id" do
      prediction_1 = build(:prediction, id: "1", trip_id: "t1")
      prediction_2 = build(:prediction, id: "2", trip_id: "t2")

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2])

      assert [prediction_1] ==
               Enum.sort_by(Store.Predictions.fetch(trip_id: "t1"), & &1.id)
    end

    test "logs duration" do
      set_log_level(:info)
      prediction_1 = build(:prediction, id: "1", stop_id: "12345")

      Store.Predictions.process_upsert(:add, [prediction_1])
      msg = capture_log([level: :info], fn -> Store.Predictions.fetch(stop_id: "12345") end)

      assert msg =~
               "fetch table_name=predictions_from_streams fetch_keys=[stop_id: \"12345\"] duration="
    end
  end

  describe "fetch list of keywords" do
    test "fetches all matches from multiple fetch keys" do
      prediction_1 = build(:prediction, id: "1", stop_id: "12345")
      prediction_2 = build(:prediction, id: "2", stop_id: "6789")
      prediction_3 = build(:prediction, id: "3", stop_id: "00000")

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2, prediction_3])

      assert [prediction_1, prediction_2] ==
               Enum.sort_by(
                 Store.Predictions.fetch([[stop_id: "12345"], [stop_id: "6789"]]),
                 & &1.id
               )
    end
  end

  describe "fetch_with_associations/1" do
    test "fetches all associated trips and vehicles", %{
      prediction_1: prediction_1,
      prediction_2: prediction_2,
      trip_1: trip_1,
      trip_2: trip_2,
      vehicle_1: vehicle_1,
      vehicle_2: vehicle_2
    } do
      prediction_without_trip = build(:prediction, trip_id: nil, stop_id: prediction_1.stop_id)

      prediction_without_vehicle =
        build(:prediction, trip_id: "trip_1", stop_id: prediction_1.stop_id, vehicle_id: nil)

      prediction_other_stop =
        build(:prediction, stop_id: "other", trip_id: "other_trip", vehicle_id: "other_vehicle")

      trip_other_stop = build(:trip, id: "other_trip")
      other_vehicle = build(:vehicle, id: "other_vehicle")

      Store.Predictions.process_upsert(:add, [
        prediction_1,
        prediction_2,
        prediction_without_trip,
        prediction_without_vehicle,
        prediction_other_stop,
        trip_1,
        trip_2,
        trip_other_stop
      ])

      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2, other_vehicle])

      assert JsonApi.Object.to_full_map([
               prediction_1,
               prediction_2,
               prediction_without_trip,
               prediction_without_vehicle,
               trip_1,
               trip_2,
               vehicle_1,
               vehicle_2
             ]) == Store.Predictions.fetch_with_associations(stop_id: "12345")

      assert JsonApi.Object.to_full_map([
               prediction_1,
               prediction_2,
               prediction_without_trip,
               prediction_without_vehicle,
               prediction_other_stop,
               trip_1,
               trip_2,
               trip_other_stop,
               vehicle_1,
               vehicle_2,
               other_vehicle
             ]) ==
               Store.Predictions.fetch_with_associations([[stop_id: "12345"], [stop_id: "other"]])
    end

    test "when prediction has no associations, returns no associations" do
      prediction = build(:prediction, id: "p_1", stop_id: "12345", vehicle_id: nil, trip_id: nil)
      trip = build(:trip, id: "t_1")
      vehicle = build(:vehicle)

      Store.Predictions.process_upsert(:add, [prediction, trip])
      Store.Vehicles.process_upsert(:add, [vehicle])

      assert JsonApi.Object.to_full_map([
               prediction
             ]) ==
               Store.Predictions.fetch_with_associations([[stop_id: "12345"]])
    end
  end
end

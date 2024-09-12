defmodule MBTAV3API.Store.PredictionsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Test.Support.Helpers
  import Test.Support.Sigils

  alias MBTAV3API.{JsonApi.Reference, Store}

  describe "process_events" do
    setup do
      start_link_supervised!(Store.Predictions)
      :ok
    end

    test "process_upsert when add" do
      prediction_1 = build(:prediction, id: "1", stop_id: "12345")
      prediction_2 = build(:prediction, id: "2", stop_id: "12345")

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2])

      assert [prediction_1, prediction_2] ==
               Enum.sort_by(Store.Predictions.fetch(stop_id: "12345"), & &1.id)
    end

    test "process_upsert when update" do
      prediction_1 = build(:prediction, id: "1", stop_id: "12345")
      prediction_2 = build(:prediction, id: "2", stop_id: "12345")

      prediction_1_update =
        build(:prediction, id: "1", stop_id: "12345", departure_time: ~B[2024-03-20 16:42:01])

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2])
      Store.Predictions.process_upsert(:update, [prediction_1_update])

      assert [prediction_1_update, prediction_2] ==
               Enum.sort_by(Store.Predictions.fetch(stop_id: "12345"), & &1.id)
    end

    test "process_remove" do
      prediction_1 = build(:prediction, id: "1", stop_id: "12345")
      prediction_2 = build(:prediction, id: "2", stop_id: "12345")

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2])
      Store.Predictions.process_remove([%Reference{type: "prediction", id: "1"}])

      assert [prediction_2] ==
               Enum.sort_by(Store.Predictions.fetch(stop_id: "12345"), & &1.id)
    end

    test "process_reset" do
      prediction_66 = build(:prediction, id: "1", stop_id: "12345", route_id: "66")
      prediction_66_2 = build(:prediction, id: "2", stop_id: "12345", route_id: "66")
      prediction_39 = build(:prediction, id: "3", stop_id: "12345", route_id: "39")

      Store.Predictions.process_upsert(:add, [prediction_66, prediction_39])
      Store.Predictions.process_reset([prediction_66_2], route_id: "66")

      assert [prediction_66_2, prediction_39] ==
               Enum.sort_by(Store.Predictions.fetch(stop_id: "12345"), & &1.id)
    end
  end

  describe "fetch" do
    setup do
      start_link_supervised!(Store.Predictions)
      :ok
    end

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
               "Elixir.MBTAV3API.Store.Predictions fetch predictions fetch_keys=[stop_id: \"12345\"] duration_ms="
    end
  end

  describe "fetch_any" do
    setup do
      start_link_supervised!(Store.Predictions)
      :ok
    end

    test "process_upsert when add" do
      prediction_1 = build(:prediction, id: "1", stop_id: "12345")
      prediction_2 = build(:prediction, id: "2", stop_id: "6789")
      prediction_3 = build(:prediction, id: "3", stop_id: "00000")

      Store.Predictions.process_upsert(:add, [prediction_1, prediction_2, prediction_3])

      assert [prediction_1, prediction_2] ==
               Enum.sort_by(
                 Store.Predictions.fetch_any([[stop_id: "12345"], [stop_id: "6789"]]),
                 & &1.id
               )
    end
  end
end

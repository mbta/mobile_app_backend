defmodule MBTAV3API.Store.VehiclesTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import MBTAV3API.JsonApi.Object, only: [to_full_map: 1]
  import MobileAppBackend.Factory
  import Test.Support.Helpers

  alias MBTAV3API.JsonApi
  alias MBTAV3API.{JsonApi.Reference, Store}

  setup do
    start_link_supervised!(Store.Vehicles)
    vehicle_1 = build(:vehicle, id: "v_1", route_id: "66")
    vehicle_2 = build(:vehicle, id: "v_2", route_id: "66")

    %{
      vehicle_1: vehicle_1,
      vehicle_1_updated: %{vehicle_1 | route_id: "39"},
      vehicle_2: vehicle_2,
      vehicle_2_updated: %{vehicle_2 | route_id: "15"}
    }
  end

  describe "process_events" do
    test "process_upsert when add", %{
      vehicle_1: vehicle_1,
      vehicle_2: vehicle_2
    } do
      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2])

      assert to_full_map([vehicle_1, vehicle_2]) == Store.Vehicles.fetch_with_associations([])
    end

    test "process_upsert when update", %{
      vehicle_1: vehicle_1,
      vehicle_1_updated: vehicle_1_updated,
      vehicle_2: vehicle_2
    } do
      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2])

      assert to_full_map([vehicle_1, vehicle_2]) == Store.Vehicles.fetch_with_associations([])

      Store.Vehicles.process_upsert(:update, [vehicle_1_updated])

      assert to_full_map([vehicle_1_updated, vehicle_2]) ==
               Store.Vehicles.fetch_with_associations([])
    end

    test "process_remove", %{
      vehicle_1: vehicle_1,
      vehicle_2: vehicle_2
    } do
      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2])

      Store.Vehicles.process_remove([
        %Reference{type: "vehicle", id: vehicle_1.id}
      ])

      assert to_full_map([vehicle_2]) ==
               Store.Vehicles.fetch_with_associations([])
    end

    test "process_reset", %{
      vehicle_1: vehicle_1,
      vehicle_1_updated: vehicle_1_updated,
      vehicle_2: vehicle_2
    } do
      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2])
      Store.Vehicles.process_reset([vehicle_1_updated], [])

      assert to_full_map([vehicle_1_updated]) ==
               Store.Vehicles.fetch_with_associations([])
    end
  end

  describe "fetch" do
    test "by id", %{vehicle_1: vehicle_1, vehicle_2: vehicle_2} do
      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2])

      assert [vehicle_1] == Store.Vehicles.fetch(id: "v_1")
    end

    test "by route_id", %{vehicle_1: vehicle_1, vehicle_2_updated: vehicle_2_updated} do
      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2_updated])

      assert [vehicle_1] == Store.Vehicles.fetch(route_id: "66")
    end

    test "logs duration", %{vehicle_1: vehicle_1} do
      set_log_level(:info)

      Store.Vehicles.process_upsert(:add, [vehicle_1])
      msg = capture_log([level: :info], fn -> Store.Vehicles.fetch(id: "v_1") end)

      assert msg =~
               "Elixir.MBTAV3API.Store.Vehicles.Impl fetch table_name=vehicles_from_stream fetch_keys=[id: \"v_1\"] duration="
    end
  end

  describe "fetch list of keywords" do
    test "fetches all matches from multiple fetch keys", %{
      vehicle_1: vehicle_1,
      vehicle_2: vehicle_2
    } do
      Store.Vehicles.process_upsert(:add, [vehicle_1, vehicle_2])

      assert [vehicle_1, vehicle_2] ==
               Enum.sort_by(
                 Store.Vehicles.fetch([[id: "v_1"], [id: "v_2"]]),
                 & &1.id
               )
    end
  end

  describe "fetch_with_associations/1" do
    test "returns matching vehicles only", %{vehicle_1: vehicle_1, vehicle_2: vehicle_2} do
      Store.Vehicles.process_upsert(:add, [
        vehicle_1,
        vehicle_2
      ])

      assert to_full_map([
               vehicle_1
             ]) == Store.Vehicles.fetch_with_associations(id: "v_1")

      assert to_full_map([vehicle_1, vehicle_2]) ==
               Store.Vehicles.fetch_with_associations([[id: "v_1"], [id: "v_2"]])
    end
  end
end

defmodule MBTAV3API.Store.AlertsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import MobileAppBackend.Factory
  import Test.Support.Helpers

  alias MBTAV3API.{JsonApi.Reference, Store}

  setup do
    start_link_supervised!(Store.Alerts)
    alert_1 = build(:alert, id: "a_1", effect: :shuttle)
    alert_2 = build(:alert, id: "a_2", effect: :detour)

    %{
      alert_1: alert_1,
      alert_2: alert_2
    }
  end

  describe "process_events" do
    test "process_upsert when add", %{
      alert_1: alert_1,
      alert_2: alert_2
    } do
      Store.Alerts.process_upsert(:add, [alert_1, alert_2])

      assert [alert_1, alert_2] == fetch_all_sorted()
    end

    test "process_upsert when update", %{
      alert_1: alert_1,
      alert_2: alert_2
    } do
      Store.Alerts.process_upsert(:add, [alert_1, alert_2])

      alert_1_updated = %{alert_1 | description: "new_description"}

      Store.Alerts.process_upsert(:update, [alert_1_updated])

      assert [alert_1_updated, alert_2] == fetch_all_sorted()
    end

    test "process_remove", %{
      alert_1: alert_1,
      alert_2: alert_2
    } do
      Store.Alerts.process_upsert(:add, [alert_1, alert_2])

      Store.Alerts.process_remove([
        %Reference{type: "alert", id: alert_1.id}
      ])

      assert [alert_2] == fetch_all_sorted()
    end

    test "process_reset", %{
      alert_1: alert_1,
      alert_2: alert_2
    } do
      Store.Alerts.process_upsert(:add, [alert_1, alert_2])

      alert_1_updated = %{alert_1 | description: "new_description"}

      Store.Alerts.process_reset([alert_1_updated], [])

      assert [alert_1_updated] == fetch_all_sorted()
    end
  end

  describe "fetch" do
    test "by id", %{alert_1: alert_1, alert_2: alert_2} do
      Store.Alerts.process_upsert(:add, [alert_1, alert_2])

      assert [alert_1] == Store.Alerts.fetch(id: "a_1")
    end

    test "logs duration", %{alert_1: alert_1} do
      set_log_level(:info)

      Store.Alerts.process_upsert(:add, [alert_1])
      msg = capture_log([level: :info], fn -> Store.Alerts.fetch(id: "a_1") end)

      assert msg =~
               "fetch table_name=alerts_from_stream fetch_keys=[id: \"a_1\"] duration="
    end
  end

  defp fetch_all_sorted do
    []
    |> Store.Alerts.fetch()
    |> Enum.sort_by(& &1.id)
  end
end
